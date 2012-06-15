require 'rack'
require 'domainagechecker'
require 'json'

class WebResolver
  def initialize
    @resolver=DomainAgeChecker.new
  end

  def call(env)
    req = Rack::Request.new(env)
    code=200
    if dom=req.GET["domain"]
      begin
        res=@resolver.query(dom)
        body=JSON.generate res
      rescue DomainAgeCheckerException =>e
        code=500
        body=JSON.generate :exception => e.class , :message => e.message, :type =>e.type
      rescue
        code=500
        body=JSON.generate :error => $!
      end
      res = Rack::Response.new("",code,header={'Content-Type'=>'text/json'})
      res.write body
      res.finish
    else
    	res=Rack::Response.new("this game has no name",200,header={'Content-Type'=>'text/plain'})
	    res.finish
    end
	    
  end
end
