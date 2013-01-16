

RSpec.configure do |config|
  config.mock_framework = :mocha
end
require_relative '../lib/domainagechecker'
require 'whois'
GOOGLE_COM_REG_TIME_UTC=874306800

require "log4r"
def setupLogger  
    return Log4r::Logger.root
  end
LOGGER=setupLogger()
describe DomainAgeChecker, "#query" do
  it "takes both host and domain as input and returns domain age" do
    d=DomainAgeChecker.new :logger => LOGGER
    q=d.query "www.google.com", true
    q['created_on'].to_i.should eq(GOOGLE_COM_REG_TIME_UTC)
  end


  it "raises a DomainNotFoundException when domain is not found" do
    d=DomainAgeChecker.new :logger => LOGGER
    expect {
      q=d.query "www.google-idontexist-and-never-will1231231231255.com"
    }.to raise_error(DomainNotFoundException)
  end

  it "tries N-1 times and succeeds on Nth" do
    saved_query=Whois::Client.new.query("google.com")
    Whois::Client.any_instance.stubs(:query).
    raises(Whois::ResponseIsThrottled).then.raises(
    Errno::ECONNRESET).then.raises(
    Whois::ResponseIsThrottled).then.returns(saved_query)
    #Whois::Client.any_instance
    d=DomainAgeChecker.new :retries => 5 , :delayBetweenRetries =>0, :logger => LOGGER
    q=d.query "www.google.com", true
    q['created_on'].to_i.should eq(GOOGLE_COM_REG_TIME_UTC)
  end

  it "tries N times and gives up " do
    
    Whois::Client.any_instance.stubs(:query).raises(Whois::ResponseIsThrottled)
    d=DomainAgeChecker.new :retries => 3,  :delayBetweenRetries => 0, :logger => LOGGER
    #Whois::Client.new.query("www.lalala.com")
    expect {
    q=d.query "www.google.com", true
    }.to raise_error(DomainAgeCheckerException)
  end


end # DomainAgeChecker#query
describe DomainAgeChecker, "#getAge" do
  it "returns the number of days since registration as integer" do
    d=DomainAgeChecker.new :logger => LOGGER
    age=d.getAge "www.google.com"
    age.should be_a_kind_of(Fixnum)
    age.should be >=5378 # As of Jun 5, 2012
  end


it "calculates age relative to reference Date" do
    d=DomainAgeChecker.new :logger => LOGGER
    age=d.getAge "www.google.com", Time.local(2012,"Jan",1)
    
    age.should be >=5221 
  end
end
