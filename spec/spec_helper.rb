ENV['RACK_ENV'] ||= 'test'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'sidekiq-datadog'

module Mock
  class Worker
  end

  class Statsd < ::Datadog::Statsd
    def timing(stat, ms, opts={}); super(stat, 333, opts); end
    def send_to_socket(message); written.push(message); end
    def written; @written ||= []; end
  end
end
