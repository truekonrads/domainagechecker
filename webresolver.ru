$:.unshift File.expand_path("../lib",__FILE__)
require 'webresolver'
#use Rack::CommonLogger
run WebResolver.new

