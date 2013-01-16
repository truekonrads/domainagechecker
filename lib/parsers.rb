require 'date'

module Parsers
  class TCPDumpParser

    def parse_line(line)
      if m=/\s+A{1,}\?\s([^\s]+)\s\(\d+\)\s*$/.match(line)
        query=m[1]
      else
        return nil, nil
      end
      if query and m=/(\d+-\d+-\d+\s\d+:\d+:\d+\.\d+)/.match(line)
        # binding.pry
        time=DateTime.parse(m.captures[0])
      else
        time=nil
      end
      return query,time
    end

  end
end
