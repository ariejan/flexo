# Flexo

Flexo is a dynamic DNS server. It includes an update service and DNS server.

## Introduction

During a few lunchtime brakes I've coded up this dynamic DNS server to replace
the more commercial services I'm using at the moment. The problem I have with
other services like no-ip.com and dyndns.org:

* Restrictions which get in the way, like a minimum required IP changes, or
the requirement to login every 30 days.
* Stupid TLD's to choose from.
* Tons of spam for paid services.

This is just a proof of concept, use at your own risk.

## Architecture

Both DNS and the updater run in a single process using EventMachine. Redis is
used to store IP addresses, which makes lookups really fast.

For the DNS part I've used `rubydns`. The updater currently is a simple 
EventMachine connection.

## Installation

Dependencies:
 
* A moderately recent version of Redis.
* Root privileges for the DNS server to listen on port 53.

Just get the code, configure and run:

    git clone https://github.com/ariejan/flexo.git
    cd flexo
    cp config.example.yml config.yml
    vi config.yml
    sudo ruby server.rb

Update a host IP like this:

    $ telnet myserver 8889
    set hostname 1.2.3.4

Then DNS should work immediately:

    $ dig @myserver hostname.example.com

## DNS Configuration

For this to work properly, run this on a server somewhere. Heroku won't
work because of the need to access port 53.

Configure your domain's NS records to point to the IP of the host you run
Flexo on. Ideally this is a single IP, which you can configure in `config.yml`.

## Contributing

Feel free. Just for and create pull requests. Bonus points for feature branches.

Note that there are no tests at this time (it's a prototype). These should and
will be added soon.

## License

Copyright 2012 Ariejan de Vroom

Released under the MIT License.
