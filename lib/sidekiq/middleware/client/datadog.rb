require 'sidekiq'
require 'sidekiq/datadog/version'
require 'sidekiq/datadog/tag_builder'
require 'datadog/statsd'
require 'socket'

module Sidekiq
  module Middleware
    module Client
      class Datadog
        # Configure and install datadog instrumentation. Example:
        #
        #   Sidekiq.configure_client do |config|
        #     config.client_middleware do |chain|
        #       chain.add Sidekiq::Middleware::Client::Datadog
        #     end
        #   end
        #
        # You might want to also call `client_middleware` in your `configure_server` call,
        # since enqueued jobs can enqueue other jobs.
        #
        # If you have other client middleware that can stop jobs from getting pushed,
        # you might want to ensure this middleware is added last, to avoid reporting
        # enqueues that later get stopped.
        #
        # Options:
        # * <tt>:hostname</tt>    - the hostname used for instrumentation, defaults to system hostname, respects +INSTRUMENTATION_HOSTNAME+ env variable
        # * <tt>:metric_name</tt> - the metric name (prefix) to use, defaults to "sidekiq.job_enqueued"
        # * <tt>:tags</tt>        - array of custom tags, these can be plain strings or lambda blocks accepting a rack env instance
        # * <tt>:skip_tags</tt>   - array of tag names that shouldn't be emitted
        # * <tt>:statsd_host</tt> - the statsD host, defaults to "localhost", respects +STATSD_HOST+ env variable
        # * <tt>:statsd_port</tt> - the statsD port, defaults to 8125, respects +STATSD_PORT+ env variable
        # * <tt>:statsd</tt>      - custom statsd instance
        def initialize(opts = {})
          statsd_host = opts[:statsd_host] || ENV['STATSD_HOST'] || 'localhost'
          statsd_port = (opts[:statsd_port] || ENV['STATSD_PORT'] || 8125).to_i

          @metric_name  = opts[:metric_name] || 'sidekiq.job_enqueued'
          @statsd       = opts[:statsd] || ::Datadog::Statsd.new(statsd_host, statsd_port)

          # `status` is meaningless when enqueueing
          skip_tags = Array(opts[:skip_tags]) + ['status']

          @tag_builder = Sidekiq::Datadog::TagBuilder.new(
            opts[:tags],
            skip_tags,
            opts[:hostname],
          )
        end

        def call(worker_class, job, queue, _redis_pool, *)
          record(worker_class, job, queue)
          yield
        end

        private

        def record(worker_class, job, queue)
          tags = @tag_builder.build_tags(worker_class, job, queue)
          @statsd.increment @metric_name, tags: tags

          @statsd.flush if @statsd.respond_to?(:flush) # dogstatsd-ruby >= 5.0.0
        end
      end
    end
  end
end
