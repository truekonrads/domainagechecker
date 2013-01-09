Domain Age Checker
==================


By Konrads Smelkovs <konrads.smelkovs@kpmg.co.uk>. All rights reserved.


ABOUT
-----

The Domain Age Checker is a tool which reads dns queries (from tcpdump) and check the age of each domain. If the age is below a certain threshold, the tool alerts the administrator. Domain age is a good indicator of maliciousness. The more recently registered domain, the more likely it is malicious. This only applies to domains "seen" from conservative vantage points, such as commercial enterprises and does not work (too much SnR) at ISP level.

Domain Age Checker has two components - stream reader and resolver. The stream reader reads data (currently only tcpdump output) and invokes the resolver which obtains the domain age. There are three resolvers: local, remote web and remote dns. 

There are three executable files:

 *   resolver.rb:     the main executable which should be invoked with dns query data
 *   webresolver.ru:  a "remote" web resolver which the main resolver can use instead of performing lookups directly.
 *   dnsresolver.rb:  a "remote" dns resolver which the main resolver can use instead of performing lookups directly. Can be used to tunnel queries through restrictive firewalls. 

INSTALLATION
------------

DomainAgeChecker uses bundler to manage its gems. Just cd to the domainagechecker directory and do:
	bundle install

If you get build errors, then on ubuntu don't forget to do apt-get install build-essential. In addition, I had to do:
	sudo ln -s /usr/lib/x86_64-linux-gnu/libcurl.so.4 /usr/lib/x86_64-linux-gnu/libcurl.so

Domain Age Checker resolvers require a MongoDB listening on localhost without authentication.

RUNNING
-------

A quick and dirty way to run it is like this:

	sudo tcpdump -i en1 -n port 53 | ./resolver.rb --source - --streaming --log-level DEBUG

To run the web resolver, just do:

    rackup webresolver.ru -p 80 

The 'http://ec2-107-20-29-42.compute-1.amazonaws.com/' is a free resolver ran on Amazon EC2

To run the dns resolver, just do:

    sudo dnsresolver.rb -n your.dns.suffix.com
    
This will issue queries like google.com.your.dns.suffix.com. The dns resolver is set up as authorative name server for the zone your.dns.suffix.com.
You can use the DNS suffix domainage.tyrell-corp.co.uk which will lead you to a free resolver ran on Amazon EC2

It is OK if there are some errors in the output - not all registrars supply WHOIS information over WHOIS protocol.

By default, logging will be done at INFO level to STDOUT. You can chose to configure it more finely by either adjusting the log level or configuring logger using YALM configuration and the --log4r-config switch. Sample configuration is provided.