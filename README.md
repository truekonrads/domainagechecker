Domain Age Checker
==================


By Konrads Smelkovs <konrads.smelkovs@kpmg.co.uk>. All rights reserved.

INSTALLATION
------------

DomainAgeChecker uses bundler to manage its gems. Just cd to the domainagechecker directory and do:
	bundle install

If you get build errors, then on ubuntu don't forget to do apt-get install build-essential. In addition, I had to do:
	sudo ln -s /usr/lib/x86_64-linux-gnu/libcurl.so.4 /usr/lib/x86_64-linux-gnu/libcurl.so

RUNNING
-------

A quick and dirty way to run it is like this:

	sudo tcpdump -i en1 -n port 53 | ./resolver.rb -r remote --resolver-url 'http://ec2-107-20-29-42.compute-1.amazonaws.com/' --source - --streaming --log-level DEBUG

The 'http://ec2-107-20-29-42.compute-1.amazonaws.com/' is a free resolver ran on EC2
You may want to tune down the log level to INFO

