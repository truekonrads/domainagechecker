require_relative '../domainagechecker'
require 'whois'

RSpec.configure do |config|
  config.mock_framework = :mocha
end

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
 
 it "tries N times before giving up" do 
  saved_query=Whois::Client.new.query("google.com")
  Whois::Client.any_instance.stubs(:query).
          raises(Whois::ResponseIsThrottled).then.raises(
                  Errno::ECONNRESET).then.raises(
                  Whois::ResponseIsThrottled).then.returns(saved_query)
  #Whois::Client.any_instance
   d=DomainAgeChecker.new
   q=d.query "www.google.com"
   q['created_on'].to_i.should eq(GOOGLE_COM_REG_TIME)
 end  

 
 
end # DomainAgeChecker#query
describe DomainAgeChecker, "#getAge" do
 it "returns the number of days since registration as integer" do
    d=DomainAgeChecker.new
    age=d.getAge "www.google.com"
    age.should be_a_kind_of(Fixnum)
    age.should be >=5378 # As of Jun 5, 2012
  end
end