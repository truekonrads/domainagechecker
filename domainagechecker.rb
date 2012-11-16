require 'rubygems'
require 'domainatrix'
require 'mongo'
require 'whois'
require "log4r"
require "hashery"
# require "pry"
include Log4r
require 'typhoeus'
require "json"
require "date"
require 'resolv'
#There are two exception types - :permanent and :temporary
class DomainAgeCheckerException <StandardError
  attr_reader :type
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
      :logger => self.getDefaultLogger() ,
      :delayBetweenRetries => 2,
      :retries => 5,

    }
    @opts = defaults.merge opts
    @logger=@opts[:logger]

    @conn = Mongo::Connection.new
    @db = @conn['agechecker']
    @coll = @db['domains2']
    @whois = Whois::Client.new
  end

  def getDefaultLogger
    logger=Log4r::Logger.new(self.class.to_s)
    logger.outputters = Outputter.stdout
    return logger
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

   def query(host, ignoreCache = false)

      # d=Domainatrix.parse "mockfix://#{host}"
      # domain="#{d.domain}.#{d.public_suffix}"
      domain=self.getDomainFromHost(host)
      if not ignoreCache
         if doc=@coll.find('domain' =>domain).first
            return doc
         end
      end

    w=nil
    for i in 0..@opts[:retries]-1
    begin
#puts "Got this far"
      w=@whois.query domain
 #     puts "Got result for #{domain}"
      break
    rescue Whois::ResponseIsThrottled,Errno::ECONNRESET  => throttle 
 #     binding.pry
     # puts "Going #{i}..."
      if i+1==@opts[:retries] then
         raise DomainAgeCheckerException.new "Giving up after #{@opts[:retries]} attempts", :temporary
      end
      #puts @opts
      @logger.debug "Response is throttled, sleeping"
      sleep @opts[:delayBetweenRetries]
   end
    end
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

   def getDomainFromHost(host)
    begin
      d=Domainatrix.parse "mockfix://#{host}"
      domain="#{d.domain}.#{d.public_suffix}"
      return domain
    rescue # If Domainatrix can't parse, it errs ugly
      # binding.pry
      raise DomainAgeCheckerException.new "Can't parse #{host}", :permanent
    end
  end
    

end

class RemoteDomainAgeChecker <DomainAgeChecker
   def initialize (opts={})
      defaults = {
         :logger => self.getDefaultLogger()  ,
         :delayBetweenRetries => 2,
         :retries => 5,
         :maxentries => 100000
      }
      @opts = defaults.merge opts
      if not @opts[:url]
         raise ArgumentError, "Mandatory argument :url is missing!"
      end
      @cache = LRUHash.new @opts[:maxentries]
      @logger=@opts[:logger]
   end

  def query(host, ignoreCache = false)
    domain=self.getDomainFromHost(host)

    if not ignoreCache and @cache[domain]
      if @cache[domain][:success]
        return @cache[domain]
      else
        #BUG: a domainnotfound raises a permanent exception and if a domain is registered after this is cached,
        # it won't be checked
        if @cache[domain].is_a? DomainAgeCheckerException and @cache[domain].type=:permanent
          raise @cache[domain]
        end
      end

    end
    topts={
      :headers => {
        'User-Agent' => self.class,  # UA
      },
      :connect_timeout  =>  1000,            # milliseconds
      :timeout  =>  1000,                    # milliseconds
    }

    if @opts[:http_proxy] then
      topts[:proxy] = @opts[:http_proxy]
    end

    if @opts[:proxy_username] then
      topts[:proxy_username] = @opts[:proxy_username]
      topts[:proxy_password] = @opts[:proxy_password]
    end
    # binding.pry

    for i in 0..@opts[:retries]-1
      response  = Typhoeus::Request.get("#{@opts[:url]}?domain=#{domain}",topts)
       if response.success?
         j=JSON.parse(response.body)
         j[:success]=true
         j['created_on']=DateTime.parse(j['created_on']).to_time
         @cache[domain]=j
         return j
       else
         if response.timed_out?
            if i+1==@opts[:retries] then
                     raise DomainAgeCheckerException.new "Giving up after #{@opts[:retries]} attempts", :temporary
            end
            #puts @opts
            @logger.debug "Timeout reached for domain #{domain} on try #{i} sleeping for #{@opts[:delayBetweenRetries]} seconds"
            sleep @opts[:delayBetweenRetries]
            # This hack ensures that on retries we check if some other thread has already resovled it
            return @cache[domain] if not ignoreCache and @cache[domain] and @cache[domain][:success]
               
            next
         else
            j=JSON.parse(response.body)
            cls=Kernel.get_const(j[:exception])
            if cls.is_a? DomainAgeCheckerException then
              raise cls.new j[:message], j[:type]
            else
              raise RuntimeError "Remote end said: " + j[:error]
            end
         end
      end
   end #for

  end #def query

end #class DomainAgeChecker


class RemoteDNSDomainAgeChecker <DomainAgeChecker
   def initialize (opts={})
      defaults = {
         :logger => self.getDefaultLogger()  ,
         # :delayBetweenRetries => 2,
         :retries => 5,
         :maxentries => 100000
      }
      

      @opts = defaults.merge opts
      if not @opts[:suffix]
         raise ArgumentError, "Mandatory argument :suffix is missing!"
      end
      @cache = LRUHash.new @opts[:maxentries]
      @logger=@opts[:logger]
      if @opts[:nameserver] then 
        @logger.debug("Using nameserver #{@opts[:nameserver]}")
        @resolver=Resolv::DNS.new :nameserver => [@opts[:nameserver]]

      else
        @resolver=Resolv::DNS.new
      end
   end

  def query(host, ignoreCache = false)
    domain=self.getDomainFromHost(host)
    if not ignoreCache and @cache[domain]
      if @cache[domain][:success]
        return @cache[domain]
      else
        #BUG: a domainnotfound raises a permanent exception and if a domain is registered after this is cached,
        # it won't be checked
        if @cache[domain].is_a? DomainAgeCheckerException and @cache[domain].type=:permanent
          raise @cache[domain]
        end
      end
    end
    
    dnsquery="#{host}.#{@opts[:suffix]}"
    @logger.debug("Using #{dnsquery} for DNS query")
    for i in 0..@opts[:retries]-1
      begin
        r=@resolver.getresource(dnsquery,Resolv::DNS::Resource::IN::TXT)
        record={ :success=>true, 'created_on' => DateTime.parse(r.strings[0]).to_time}
        @cache[domain]=record
        return record
      rescue Resolv::ResolvError =>e
          raise DomainAgeCheckerException.new "Unabe to resolve domain", :permanent
      rescue Resolv::ResolvTimeout =>e
            if i+1==@opts[:retries] then
                     raise DomainAgeCheckerException.new "Giving up after #{@opts[:retries]} attempts", :temporary
            end
            #puts @opts
            @logger.debug "Timeout reached for domain #{domain} on try #{i} sleeping for #{@opts[:delayBetweenRetries]} seconds"
            sleep @opts[:delayBetweenRetries]
            # This hack ensures that on retries we check if some other thread has already resovled it
            return @cache[domain] if not ignoreCache and @cache[domain] and @cache[domain][:success]
            next
      end #rescue
    end #for

  end #def query

end #class RemoteDNSDomainAgeChecker
