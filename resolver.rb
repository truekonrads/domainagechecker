#!/opt/local/bin/ruby
require 'rubygems'
require 'trollop'
require 'actionpool'
require "log4r"
# require 'queue'
# require 'pry'
require 'domainatrix'
require 'terminal-table'
include Log4r
require_relative 'domainagechecker'
require_relative 'parsers'

RESOLVERS=%w(local http dns)
PARSERS=Parsers.constants
LEVELS=%w(DEBUG INFO WARN ERROR FATAL)
# def parse_tcpdump(line)
#    if m=/\s+A{1,}\?\s([^\s]+)\s\(\d+\)$/.match(line)
#       return m[1]
#    else
#       return nil
#    end
# end
class Resolver

  def initialize
    @domains=Hash.new
    # @@format = {
    #   'tcpdump' => method(:parse_tcpdump)

    # }
    # @queue = Queue.new
    @source = STDIN
    @parse_func = nil
    @mylog = Log4r::Logger.new 'resolver'
    # require 'pry'
    # binding.pry
    @mylog.outputters = Outputter.stdout
    # p @mylog
    # @mylog.outputters = Outputter.stdout
  end
  def main
    opts = Trollop::options do
      version "resolver v0.1a by Konrads Smelkovs"
      # banner <<-EOS
      #     Test is an awesome program that does something very, very important.
      #
      #     Usage:
      #            test [options] <filenames>+
      #     where [options] are:
      #     EOS
      opt :resolver, "Which resolver to use, supported resolvers: " + RESOLVERS.join(", "), :type => :string
      opt :threads, "How many threads to use (at this side)", :type => :int, :default =>1
      opt :max_tasks, "Maximum queue length", :type => :int, :default => 1000
      opt :timeout, "How long to wait before aborting task", :type=> :int, :default => 10
      opt :source, "Where to read data from, '-' for stdin", :default =>'-'
      opt :format, "Which parser to use: " + PARSERS.join(",") , :default => 'TCPDumpParser'
      opt :streaming, "Run in streaming mode"
      opt :alert_age , "below what age should an alert be generated", :default => 90, :type => :int
      opt :resolver_url, "The URL for remote resolver", :type=>:string
      opt :http_proxy, "HTTP Proxy for use by remote resolver", :type=>:string
      opt :proxy_user ,"Proxy username", :type=>:string
      opt :proxy_password, "Proxy password", :type=>:string
      opt :nameserver, "Namserver to use with DNS resolver", :type => :string
      opt :dnssuffix, "DNS suffix for use with DNS resolver", :type =>:string
      opt :log_level, "log level, valid options are" + LEVELS.join(", "), :type => :string, :default=>'INFO'
    end

    Trollop::die :threads , "must be larger than 0" if opts[:threads]<1
    Trollop::die :max_tasks , "must be larger than 0" if opts[:max_tasks]<1
    Trollop::die :resolver, "unknown resolver #{opts[:resolver]}" if not RESOLVERS.include? opts[:resolver]
    Trollop::die :log_level, "unknown log level #{opts[:log_level]}" if not LEVELS.include? opts[:log_level]
    Trollop::die :dnssuffix, "DNS suffix is mandatory with DNS resolver" if opts[:resolver] == "dns" and not opts[:dnssuffix]
    # binding.pry
    @mylog.level=Log4r.const_get(opts[:log_level])
    if opts[:source]=='-'
      @source=STDIN
    else
      @source=File.open(opts[:source],"rb")
    end

    # Map resolvers
    case opts[:resolver]
    when "local"
      resolver=DomainAgeChecker.new :logger => @mylog
    when "http"
      args={
         :logger => @mylog, :url => opts[:resolver_url]
      }
      if opts[:http_proxy]
         args[:http_proxy]=opts[:http_proxy]
         if opts[:proxy_user] then
            args[:proxy_user] = opts[:proxy_user]
            args[:proxy_password] = opts[:proxy_password]
         end
      end

      resolver=RemoteDomainAgeChecker.new args
    when "dns"
      args={
         :logger => @mylog, :url => opts[:resolver_url],
         :suffix => opts[:dnssuffix]
      }
      if opts[:nameserver]
        args[:nameserver]=opts[:nameserver]
      end
      resolver=RemoteDNSDomainAgeChecker.new args
    end
    # binding.pry
    @parse_func=(Parsers.const_get opts[:format]).new




    pool = ActionPool::Pool.new(
      :min_threads => 1,
      :max_threads => opts[:threads],
      :a_to => opts[:timeout]
    )

    func=@parse_func
    log=@mylog
    alert_age=opts[:alert_age]
    @source.each { |l|
      begin
        diff=pool.action_size - opts[:max_tasks]
        while (opts[:max_tasks] - pool.action_size) <0 do
            log.debug("Sleeping as task count is #{pool.action_size}")
            sleep(2)
          end
          (host,time) = func.parse_line l
          # host=@parse_func(l)
          next if not host
          d=Domainatrix.parse "mockfix://#{host}"
          domain="#{d.domain}.#{d.public_suffix}"
          
          if @domains.include? domain
            @domains[domain][:hits]+=1
            next
          else
            log.debug "Resolving #{domain}"
            pool.queue Proc.new {|dom, store, res,log,time,alert_age|  resolveDomain(dom,store,res,log,time,alert_age)}, domain.dup,@domains,resolver,log,time,alert_age
          end
        rescue => e
          log.error "Something went wrong: #{e.message}"
        end
        }


        while pool.action_size >0 do
            log.debug("Waiting for pool to finish, #{pool.action_size} tasks left")
            sleep 2
          end
          pool.shutdown
          if not opts[:streaming]
            reduced=@domains.delete_if{|k,v| not v[:age]}
            # p reduced
            sorted=reduced.sort_by {|k,v| v[:age]}.map {|k,v| [k,v[:age],v[:hits]]}

            puts Terminal::Table.new :title => "Summary",
              :headings => ['Domain', 'Age','Hits'],
              :rows => sorted
          end
        end


      end

      def resolveDomain(dom,domains,res,log,referenceTime=nil,alert_age=90)
        if referenceTime == nil then
          referenceTime=Time.now
        end
        begin

          domains[dom]={:hits => 1, :age => nil}
          age=res.getAge(dom,referenceTime)
          domains[dom][:age]=age

        rescue DomainAgeCheckerException => e
          domains[dom][:error]=e.message
        rescue =>e
          log.error "Unhandled exception: #{e.message}"
          log.error "Backtrace: #{e.backtrace.join('\n\t')}"
          # binding.pry
          return
        end
        if age and age <= alert_age
          log.info "The domain #{dom} is only #{age} days old"
        end
        log.debug "Resolved #{dom}, age #{domains[dom][:age]} days"

      end
      if __FILE__ == $0
        Resolver.new().main
      end
