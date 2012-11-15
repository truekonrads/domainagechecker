# DNS Resolver
require 'rubygems'
require 'rubydns'
require_relative 'domainagechecker'
require 'trollop'
require 'time'
$R = Resolv::DNS.new
SUFFIX="whoislookup.tyrell-corp.co.uk"
require 'pry'
resolver=DomainAgeChecker.new
RubyDNS::run_server do
    Name = Resolv::DNS::Name
    IN = Resolv::DNS::Resource::IN    

    match(/^([.\w]+)\.#{SUFFIX}$/, IN::TXT) do |match_data, transaction|
        begin
        res=resolver.query(match_data[1])
        # binding.pry
        created_on=res['created_on']
        refTime=Time.now
        age=((refTime - created_on)/ (60*60*24)).round
        # logger.debug("Responding for #{match_data} with #{age} which was created #{created_on}")
        # transaction.respond!(age.to_s)
        logger.debug("Responding for #{match_data} which was created #{created_on.to_s}")
        transaction.respond!(created_on.to_s)
      rescue DomainNotFoundException =>e
      	transaction.failure!(:NXDomain)
      	logger.error(e.to_s)
      rescue DomainAgeCheckerException =>e
        transaction.failure!(:ServFail)      
        logger.error(e.to_s)
      rescue => e
        transaction.failure!(:ServFail)
        raise e
       end
    end

    # Default DNS handler
    otherwise do |transaction|
    	transaction.failure!(:ServFail)        
    end
end