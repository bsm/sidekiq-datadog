require 'sidekiq'
require 'sidekiq/datadog/version'
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
          @tags         = opts[:tags] || []
          @skip_tags    = Array(opts[:skip_tags]).map(&:to_s)

          env  = Sidekiq.options[:environment] || ENV['RACK_ENV']
          host = opts[:hostname] || ENV['INSTRUMENTATION_HOSTNAME'] || Socket.gethostname
          setup_defaults(host: host, env: env)
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
          tags = build_tags(worker, job, queue, error)

          @statsd.increment @metric_name, tags: tags
          @statsd.timing "#{@metric_name}.time", msec, tags: tags

          return unless job['enqueued_at']

          queued_ms = ((start - Time.at(job['enqueued_at'])) * 1000).round
          @statsd.timing "#{@metric_name}.queued_time", queued_ms, tags: tags
        end

        def build_tags(worker, job, queue = nil, error = nil)
          name = underscore(job['wrapped'] || worker.class.to_s)
          tags = @tags.flat_map do |tag|
            case tag
            when String then tag
            when Proc then tag.call(worker, job, queue, error)
            end
          end
          tags.compact!

          tags.push "name:#{name}" if include_tag?('name')
          tags.push "queue:#{queue}" if queue && include_tag?('queue')

          if error.nil?
            tags.push 'status:ok' if include_tag?('status')
          else
            kind = underscore(error.class.name.sub(/Error$/, ''))
            tags.push 'status:error' if include_tag?('status')
            tags.push "error:#{kind}" if include_tag?('error')
          end

          tags
        end

        def setup_defaults(hash)
          hash.each do |key, val|
            key = key.to_s
            next unless val && include_tag?(key)

            prefix = "#{key}:"
            next if @tags.any? {|t| t.is_a?(String) && t.start_with?(prefix) }

            @tags.push [key, val].join(':')
          end
        end

        def include_tag?(tag)
          !@skip_tags.include?(tag)
        end

        def underscore(word)
          word = word.to_s.gsub(/::/, '/')
          word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          word.tr!('-', '_')
          word.downcase
        end
      end
    end
  end
end
