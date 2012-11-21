require 'rubygems'
require 'bundler'

Bundler.setup

require 'eventmachine'
require 'em-redis'
require 'rubydns'
require 'rubydns/system'
require 'settingslogic'

# Pass-through DNS requests to the system configured nameservers.
R = RubyDNS::Resolver.new(RubyDNS::System::nameservers)

Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

module Flexo
  def self.root
    @root ||= File.expand_path("..", __FILE__)
  end

  def self.env
    @env ||= ENV["RACK_ENV"] || "development"
  end

  class Settings < Settingslogic
    source "#{Flexo.root}/config.yml"
    namespace Flexo.env
  end

  class Connection < EM::Connection
    def post_init
    end

    def unbind
    end

    def receive_data(data)
      handle_message(data)
    end

    def redis
      @redis ||= EM::Protocols::Redis.connect
    end

  private
    # Send a reply and close the connection.
    def reply(msg)
      send_data("#{msg}\n")
      close_connection
    end

    # Handle an incoming message
    def handle_message(msg)
      case msg
      when /^set (.+) (.+)$/ then update_ip_for_host($1.strip, $2.strip)
      when /^get (.+)$/ then get_ip_for_host($1.strip)
      else
        reply "Sorry, I don't know what you want."
      end
    end

    # Updates or sets the IP for a givne hostname
    def update_ip_for_host(hostname, ip)
      redis.set "ip:#{hostname}", ip do |reponse|
        reply("#{hostname} updated to #{ip}.")
      end
    end

    # Retrieve the IP for the specified hostname
    def get_ip_for_host(hostname)
      redis.get "ip:#{hostname}" do |response|
        reply("#{hostname} points to #{response || "127.0.0.1"}.")
      end
    end
  end
end

# Listen on UDP and TCP port 53 by default.
INTERFACES = [
  [:udp, Flexo::Settings.dns.listen, Flexo::Settings.dns.port],
  [:tcp, Flexo::Settings.dns.listen, Flexo::Settings.dns.port]
]

# Do the EventMachine dance
EM.run do
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

  # Listen for connection on 8080 to accept DNS updates.
  EM.start_server Flexo::Settings.updater.listen,
                  Flexo::Settings.updater.port,
                  Flexo::Connection

  # Ruby DNS handles DNS lookups.
  RubyDNS::run_server(listen: INTERFACES) do
    redis = EM::Protocols::Redis.connect

    # Ah, we know about this domain, let's look that up for you.
    match(/(.+).#{Flexo::Settings.tld}$/, IN::A) do |match, transaction|
      transaction.defer!

      hostname = match[1].strip

      redis.get "ip:#{hostname}" do |response|
        transaction.respond!(response || "127.0.0.1")
      end
    end

    # Nope, we don't know anything about that DNS request,
    # pass it on to other, more knowledgable servers.
    otherwise do |transaction|
      logger.info "Passing DNS request upstream..."
      transaction.passthrough!(R)
    end
  end
end
