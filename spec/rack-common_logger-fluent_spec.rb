require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RackCommonLoggerFluent" do
  before do
    body = "foobar"
    @app = Rack::Lint.new(lambda {|env|
      [200, { "Content-Type" => "text/html", "Content-Length" => body.size.to_s }, [body] ]
    })
  end

  it do
    logger = Fluent::Logger::TestLogger.new
    res = Rack::MockRequest.new(Rack::CommonLogger::Fluent.new(@app, 'myapp', logger)).get('/')
    logger.queue.size.should == 1
    message = logger.queue.first
    message["hostname"].should == "example.org"
    message["content_length"].should == 6
    message["content_type"].should == "text/html"
    message["request_method"].should == "GET"
    message["path_info"].should == "/"
    message["http_status"].should == 200
  end
end
