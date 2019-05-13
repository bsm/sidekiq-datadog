ENV['RACK_ENV'] ||= 'test'
require 'sidekiq-datadog'
require 'timecop'

module Mock
  class Worker; end

  class Statsd < ::Datadog::Statsd
    def send_stat(message)
      messages.push message
    end

    def messages
      @messages ||= []
    end
  end
end
