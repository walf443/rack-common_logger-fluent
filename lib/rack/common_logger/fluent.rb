require 'fluent-logger'
require 'time'

module Rack
  class CommonLogger
    #
    # @example
    #   # in your config.ru
    #
    #   require 'fluent-logger'
    #   require 'rack/common_logger/fluent'
    #
    #   logger = Fluent::Logger::FluentLogger.new(nil, :host => 'localhost', :port => 24224)
    #   use Rack::CommonLogger::Fluent, 'myapp.access', logger
    #   # will output to log
    #   #   #=> 2012-05-12T17:56:50+09:00       myapp.access      {"remote_addr":"127.0.0.1","accessed_at":"2012-05-12T17:56:50+09:00","request_method":"GET","path_info":"/","query_string":"?body=1","http_version":"HTTP/1.1","http_status":304,"user_agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.168 Safari/535.19","content_type":null,"content_length":null,"runtime":0.007976}
    #
    #   # if you want to customize format
    #   use Rack::CommonLogger::Fluent, 'myapp', logger do |info|
    #     result = {}
    #
    #     # ...
    #
    #     result
    #   end
    # 
    class Fluent
      def initialize(app, tag, logger=nil, &format)
        @app = app
        @logger = logger || ::Fluent::Logger::FluentLogger.new(nil, :host => 'localhost', :port => 24224)
        @tag = tag
        @format = format || lambda do |info|
          self.default_format(info)
        end
      end

      def call(env)
        began_at = Time.now
        status, header, body = @app.call(env)
        header = Utils::HeaderHash.new(header)
        body = BodyProxy.new(body) { log(env, status, header, began_at) }
        [status, header, body]
      end

      def default_format(info)
          hash = {}

          hash["remote_addr"]    = info[:env]["HTTP_X_FORWARDED_FOR"] || info[:env]["REMOTE_ADDR"] || nil
          hash["accessed_at"]    = info[:now].iso8601
          hash["request_method"] = info[:env]["REQUEST_METHOD"]
          hash["path_info"]      = info[:env]["PATH_INFO"].gsub("%2F", '/') # some case "/" to be %2F.
          hash["query_string"]   = info[:env]["QUERY_STRING"].empty? ? "" : '?' + info[:env]["QUERY_STRING"]
          hash["http_version"]   = info[:env]["HTTP_VERSION"]
          hash["http_status"]    = info[:status].to_s[0..3].to_i
          hash["user_agent"]     = info[:env]["HTTP_USER_AGENT"]
          hash["content_type"]   = info[:header]["Content-Type"]
          hash["content_length"] = info[:header]["Content-Length"] ? info[:header]["Content-Length"].to_i : nil
          hash["runtime"]        = info[:runtime]

          hash
      end

      def log(env, status, header, began_at)
        now = Time.now
        result = @format.call({ :env => env, :status => status, :header => header, :now => now, :runtime => now - began_at })
        @logger.post(@tag, result)
      end

    end
  end
end

