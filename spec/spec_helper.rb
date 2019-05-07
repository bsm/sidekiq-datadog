ENV['RACK_ENV'] ||= 'test'
require 'sidekiq-datadog'

module Mock
  class Worker
  end

  class Statsd < ::Datadog::Statsd
    def timing(stat, _millis, opts={})
      super(stat, 333, opts)
    end

    def send_stat(message)
      messages.push message
    end

    def messages
      @messages ||= []
    end
  end
end
