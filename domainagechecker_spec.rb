require_relative 'domainagechecker'
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
 
 
end
