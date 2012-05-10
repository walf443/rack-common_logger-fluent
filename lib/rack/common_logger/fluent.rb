require 'fluent-logger'

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
    #   use Rack::CommonLogger::Fluent, 'myapp', logger
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

          hash["remote_addr"]    = info[:env]["HTTP_X_FORWARDED_FOR"] || info[:env]["REMOTE_ADDR"] || '-'
          hash["accessed_at"]    = info[:now].strftime('%d/%b/%Y %H:%M:%S')
          hash["request_method"] = info[:env]["REQUEST_METHOD"]
          hash["path_info"]      = info[:env]["PATH_INFO"]
          hash["query_string"]   = info[:env]["QUERY_STRING"].empty? ? "" : '?' + info[:env]["QUERY_STRING"]
          hash["http_version"]   = info[:env]["HTTP_VERSION"]
          hash["http_status"]    = info[:status].to_s[0..3]
          hash["content_length"] = info[:length].to_i
          hash["runtime"]        = info[:runtime]

          hash
      end

      def log(env, status, header, began_at)
        now = Time.now
        length = extract_content_length(header)
        result = @format.call({ :env => env, :status => status, :header => header, :now => now, :runtime => now - began_at, :length => length })
        @logger.post(@tag, result)
      end

      def extract_content_length(headers)
        value = headers['Content-Length'] or return '-'
        value.to_s == '0' ? '-' : value
      end
    end
  end
end

