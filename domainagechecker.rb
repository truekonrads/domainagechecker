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
  
  def initialize
    @conn = Mongo::Connection.new
    @db = @conn['agechecker']
    @coll = @db['domains']
    @whois = Whois::Client.new
  end
  
  #Get the creation date of a domain and return a hash
  #with domain and creation date (Time)
  #throws DomainAgeCheckerException
  def query(host)
    d=Domainatrix.parse "mockfix://#{host}"
    domain="#{d.domain}.#{d.public_suffix}"
    if doc=@coll.find('domain' =>domain).first
      return doc
    end
    w=@whois.query domain
    if w.parser.registered?
      if w.created_on
        doc={'domain'=>domain,'created_on'=>w.created_on}
        @coll.insert doc
      else
        errmsg="Could not parse WHOIS record for #{domain}"
        log.error msg
        raise DomainAgeCheckerException, msg, :permanent
      end
    else
      raise DomainNotFoundException, domain
    end
    return doc
  end
end