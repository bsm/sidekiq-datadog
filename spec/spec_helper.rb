ENV['RACK_ENV'] ||= 'test'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'sidekiq-datadog'

module Mock
  class Worker
  end

  class Statsd < ::Statsd
    def timing(stat, ms, opts={}); super(stat, 333, opts); end
    def flush_buffer; end
    alias :send_stat :send_to_buffer
  end
end
