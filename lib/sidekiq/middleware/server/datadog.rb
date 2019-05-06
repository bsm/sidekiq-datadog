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
          hostname      = opts[:hostname] || ENV['INSTRUMENTATION_HOSTNAME'] || Socket.gethostname
          statsd_host   = opts[:statsd_host] || ENV['STATSD_HOST'] || "localhost"
          statsd_port   = (opts[:statsd_port] || ENV['STATSD_PORT'] || 8125).to_i

          @metric_name  = opts[:metric_name] || "sidekiq.job"
          @statsd       = opts[:statsd] || ::Datadog::Statsd.new(statsd_host, statsd_port)
          @tags         = opts[:tags] || []
          @skipped_tags = (opts[:skip_tags] || []).map(&:to_s)

          if include_tag?(:host) && @tags.none? { |t| t =~ /^host\:/ }
            @tags.push("host:#{hostname}")
          end

          env = Sidekiq.options[:environment] || ENV['RACK_ENV']
          if env && include_tag?(:env) && @tags.none? { |t| t =~ /^env\:/ }
            @tags.push("env:#{ENV['RACK_ENV']}")
          end
        end

        def call(worker, job, queue, *)
          start = Time.now
          begin
            yield
            record(worker, job, queue, start)
          rescue StandardError => e
            record(worker, job, queue, start, e)
            raise
          end
        end

        private

        def record(worker, job, queue, start, error = nil)
          ms = ((Time.now - start) * 1000).round
          name = underscore(job['wrapped'] || worker.class.to_s)
          tags = @tags.flat_map do |tag|
            case tag
            when String then tag
            when Proc then tag.call(worker, job, queue, error)
            end
          end

          tags.push "name:#{name}" if include_tag?(:name)
          tags.push "queue:#{queue}" if queue && include_tag?(:queue)

          if error
            kind = underscore(error.class.name.sub(/Error$/, ''))
            tags.push 'status:error' if include_tag?(:status)
            tags.push "error:#{kind}" if include_tag?(:error)
          else
            tags.push 'status:ok' if include_tag?(:status)
          end

          tags.compact!

          @statsd.increment @metric_name, tags: tags
          @statsd.timing "#{@metric_name}.time", ms, tags: tags

          if job['enqueued_at']
            queued_ms = ((start - Time.at(job['enqueued_at'])) * 1000).round
            @statsd.timing "#{@metric_name}.queued_time", queued_ms, tags: tags
          end
        end

        def include_tag?(tag)
          !@skipped_tags.include?(tag.to_s)
        end

        def underscore(word)
          word = word.to_s.gsub(/::/, '/')
          word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
          word.tr!("-", "_")
          word.downcase
        end
      end
    end
  end
end
