# DNS Resolver
require 'rubygems'
require 'rubydns'
require_relative 'lib/domainagechecker'
require 'trollop'
require 'time'
# require 'EventMachine'
$R = Resolv::DNS.new
# SUFFIX="whoislookup.tyrell-corp.co.uk"
# require 'pry'

opts = Trollop::options do
      version "dnsresolver v0.1a by Konrads Smelkovs"
      # banner <<-EOS
      #     Test is an awesome program that does something very, very important.
      #
      #     Usage:
      #            test [options] <filenames>+
      #     where [options] are:
      #     EOS
      opt :dnssuffix, "DNS Suffix", :type => :string, :required => true
      opt :mongodb_uri, "URI for mongodb if local resolver is used", :type=> :string, :default => "mongodb://localhost/"
end
# Trollop::die :dnssuffix, "Please specify DNS suffix" if not opts[:dnssuffix]
SUFFIX=opts[:dnssuffix]

resolver=DomainAgeChecker.new :mongodb_uri => opts[:mongodb_uri]
RubyDNS::run_server do
    Name = Resolv::DNS::Name
    IN = Resolv::DNS::Resource::IN    

    #match(/^([-.\w]+)\.#{SUFFIX}$/, IN::TXT) do |match_data, transaction|
    match(/^([-.\w]+)\.#{SUFFIX}$/, IN::TXT) do |transaction, match_data|
        operation = proc {
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
        # require 'pry'
        # binding.pry
        transaction.succeed
        # transaction.success!
      rescue DomainNotFoundException =>e
      	transaction.failure!(:NXDomain)
      	logger.error(e.to_s)
      rescue DomainAgeCheckerException =>e
	if e.type==:permanent then
		transaction.failure!(:NXDomain)
	else
        	transaction.failure!(:ServFail)      
        end
	logger.error(e.to_s)
      rescue => e
        transaction.failure!(:ServFail)
        logger.error(e.to_s)
       end
       }
       transaction.defer!
       EventMachine.defer operation
    end

    # Default DNS handler
    otherwise do |transaction|
    	transaction.failure!(:ServFail)        
    end
end
