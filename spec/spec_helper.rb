ENV['RACK_ENV'] ||= 'test'
require 'sidekiq-datadog'
require 'timecop'

module Mock
  class Worker; end # rubocop:disable Lint/EmptyClass

  class Statsd < ::Datadog::Statsd
    def send_stats(stat, delta, type, opts = EMPTY_OPTIONS)
      full_stat = serializer.to_stat(stat, delta, type, tags: opts[:tags])
      messages.push full_stat
    end

    def messages
      @messages ||= []
    end
  end
end
