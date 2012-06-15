require_relative '../parsers'
describe Parsers::TCPDumpParser, '#parse_line' do
  it 'returns hostname and time where time is present' do
    line='2012-06-14 08:32:21.062156 IP 192.168.1.101.57865 > 192.168.1.1.domain: 53727+ A? konrads.smelkovs.com. (38)'
    p=Parsers::TCPDumpParser.new
    (hostname,d)=p.parse_line(line)
    hostname.should eq("konrads.smelkovs.com.")
    d.to_s.should eq(DateTime.parse("2012-06-14T08:32:21+00:00").to_s)
  end
  it 'returns only hostname when time is not known' do
    line="7:50:47.750980 IP 192.168.1.101.51593 > 192.168.1.1.53: 41801+ A? bbc.co.uk. (27)"
    p=Parsers::TCPDumpParser.new
    (hostname,d)=p.parse_line(line)
    hostname.should eq("bbc.co.uk.")
    d.should eq (nil)
  end
end
