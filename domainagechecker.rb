require 'rubygems'
require 'domainatrix'
require 'mongo'
require 'whois'
require "log4r"
include Log4r


#There are two exception types - :permanent and :temporary
class DomainAgeCheckerException <StandardError
   def initialize(message, type)
      super(message)
      @type=type
   end
end

class DomainNotFoundException <DomainAgeCheckerException
   def initialize(domain)
      super "Domain '#{domain}' was not found", :permanent
   end
end

class DomainAgeChecker

   def initialize (opts={})
      defaults = {
         :logger => Logger.new("DomainAgeChecker") ,
         :delayBetweenRetries => 2,
         :retries => 5,
      }
      @opts = defaults.merge opts
      @logger=opts[:logger]

      @conn = Mongo::Connection.new
      @db = @conn['agechecker']
      @coll = @db['domains2']
      @whois = Whois::Client.new
   end

   #Get the creation date of a domain and return a hash
   #with domain and creation date (Time)
   #throws DomainAgeCheckerException
   def getAge(host, refTime = nil)
      if refTime == nil then
         refTime = Time.now
      end
      return ((refTime - self.query(host)['created_on'])/ (60*60*24)).round
   end

   def query(host)
      d=Domainatrix.parse "mockfix://#{host}"
      domain="#{d.domain}.#{d.public_suffix}"
      if doc=@coll.find('domain' =>domain).first
         return doc
      end

    w=nil
    @opts[:retries].times { |i|
    begin
      w=@whois.query domain
      break
    rescue Whois::ResponseIsThrottled,Errno::ECONNRESET  => throttle 
      if i+1==@opts[:delayBetweenRetries] then
         raise DomainAgeCheckerException "Giving up after #{@opts[:retries]} attempts"
      end
      @logger.debug "Response is throttled, sleeping"
      sleep @opts[:delayBetweenRetries]
   end
    }
      if w.parser.registered?
         if w.created_on
            doc={'domain'=>domain,'created_on'=>w.created_on}
            @coll.insert doc
         else
            errmsg="Could not parse WHOIS record for #{domain}"
            @logger.error errmsg
            raise DomainAgeCheckerException, errmsg, :permanent
         end
      else
         raise DomainNotFoundException, domain
      end
      return doc
   end
end
