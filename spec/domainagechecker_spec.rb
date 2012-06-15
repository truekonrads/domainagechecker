

RSpec.configure do |config|
  config.mock_framework = :mocha
end
require_relative '../domainagechecker'
require 'whois'
GOOGLE_COM_REG_TIME=874278000


describe DomainAgeChecker, "#query" do
  it "takes both host and domain as input and returns domain age" do
    d=DomainAgeChecker.new
    q=d.query "www.google.com"
    q['created_on'].to_i.should eq(GOOGLE_COM_REG_TIME)
  end


  it "raises a DomainNotFoundException when domain is not found" do
    d=DomainAgeChecker.new
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
    d=DomainAgeChecker.new :retries => 5 , :delayBetweenRetries =>0
    q=d.query "www.google.com", true
    q['created_on'].to_i.should eq(GOOGLE_COM_REG_TIME)
  end

  it "tries N times and gives up " do
    
    Whois::Client.any_instance.stubs(:query).raises(Whois::ResponseIsThrottled)
    d=DomainAgeChecker.new :retries => 3,  :delayBetweenRetries => 0
    #Whois::Client.new.query("www.lalala.com")
    expect {
    q=d.query "www.google.com", true
    }.to raise_error(DomainAgeCheckerException)
  end


end # DomainAgeChecker#query
describe DomainAgeChecker, "#getAge" do
  it "returns the number of days since registration as integer" do
    d=DomainAgeChecker.new
    age=d.getAge "www.google.com"
    age.should be_a_kind_of(Fixnum)
    age.should be >=5378 # As of Jun 5, 2012
  end


it "calculates age relative to reference Date" do
    d=DomainAgeChecker.new
    age=d.getAge "www.google.com", Time.local(2012,"Jan",1)
    
    age.should be >=5221 
  end
end
