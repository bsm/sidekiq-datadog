require 'sidekiq'
require 'sidekiq/datadog/version'
require 'sidekiq/datadog/tag_builder'
require 'datadog/statsd'
require 'socket'

module Sidekiq
  module Middleware
    module Server
      class Datadog
        # Configure and install datadog instrumentation. Example:
        #
        #   Sidekiq.configure_server do |config|
        #     config.server_middleware do |chain|
        #       chain.add Sidekiq::Middleware::Server::Datadog
        #     end
        #   end
        #
        # Options:
        # * <tt>:hostname</tt>    - the hostname used for instrumentation, defaults to system hostname, respects +INSTRUMENTATION_HOSTNAME+ env variable
        # * <tt>:metric_name</tt> - the metric name (prefix) to use, defaults to "sidekiq.job"
        # * <tt>:tags</tt>        - array of custom tags, these can be plain strings or lambda blocks accepting a rack env instance
        # * <tt>:skip_tags</tt>   - array of tag names that shouldn't be emitted
        # * <tt>:statsd_host</tt> - the statsD host, defaults to "localhost", respects +STATSD_HOST+ env variable
        # * <tt>:statsd_port</tt> - the statsD port, defaults to 8125, respects +STATSD_PORT+ env variable
        # * <tt>:statsd</tt>      - custom statsd instance
        def initialize(opts = {})
          statsd_host = opts[:statsd_host] || ENV['STATSD_HOST'] || 'localhost'
          statsd_port = (opts[:statsd_port] || ENV['STATSD_PORT'] || 8125).to_i

          @metric_name  = opts[:metric_name] || 'sidekiq.job'
          @statsd       = opts[:statsd] || ::Datadog::Statsd.new(statsd_host, statsd_port)
          @tag_builder  = Sidekiq::Datadog::TagBuilder.new(
            opts[:tags],
            opts[:skip_tags],
            opts[:hostname],
          )
        end

        def call(worker, job, queue, *)
          start = Time.now
          clock = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond)

          begin
            yield
            record(worker, job, queue, start, clock)
          rescue StandardError => e
            record(worker, job, queue, start, clock, e)
            raise
          end
        end

        private

        def record(worker, job, queue, start, clock, error = nil)
          msec = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond) - clock
          tags = @tag_builder.build_tags(worker, job, queue, error)

          @statsd.increment @metric_name, tags: tags
          @statsd.timing "#{@metric_name}.time", msec, tags: tags

          return unless job['enqueued_at']

          queued_ms = ((start - Time.at(job['enqueued_at'])) * 1000).round
          @statsd.timing "#{@metric_name}.queued_time", queued_ms, tags: tags
        end
      end
    end
  end
end
