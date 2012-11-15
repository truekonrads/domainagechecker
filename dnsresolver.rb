#!/usr/bin/ruby
# DNS Resolver
require 'rubygems'
require 'rubydns'
require_relative 'domainagechecker'
require 'trollop'

$R = Resolv::DNS.new
SUFFIX="whoislookup.tyrell-corp.co.uk"

resolver=DomainAgeChecker.new
RubyDNS::run_server do
    Name = Resolv::DNS::Name
    IN = Resolv::DNS::Resource::IN    

    match(/^([.\w]+)\.#{SUFFIX}$/, IN::TXT) do |match_data, transaction|
        begin
        res=resolver.query(dom)
        created_on=res['created_on']
        logger.debug("Responding for #{match_data} with #{created_on}")
        transaction.respond!(created_on)
      rescue DomainNotFoundException =>e
      	transaction.failure!(:NXDomain)
      	logger.error(e.to_s)
      rescue DomainAgeCheckerException =>e
        transaction.failure!(:ServFail)      
        logger.error(e.to_s)
       end
    end

    # Default DNS handler
    otherwise do |transaction|
    	transaction.failure!(:ServFail)        
    end
end