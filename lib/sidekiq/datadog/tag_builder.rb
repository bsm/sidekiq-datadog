module Sidekiq
  module Datadog
    class TagBuilder
      def initialize(custom_tags = [], skip_tags = [], custom_hostname = nil)
        @tags = Array(custom_tags)
        @skip_tags = Array(skip_tags).map(&:to_s)

        env  = Sidekiq.options[:environment] || ENV['RACK_ENV']
        host = custom_hostname || ENV['INSTRUMENTATION_HOSTNAME'] || Socket.gethostname
        setup_defaults(host: host, env: env)
      end

      def build_tags(worker, job, queue = nil, error = nil)
        tags = @tags.flat_map do |tag|
          case tag
          when String then tag
          when Proc then tag.call(worker, job, queue, error)
          end
        end
        tags.compact!

        tags.push "name:#{job_name(worker, job)}" if include_tag?('name')
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

      private

      def job_name(worker, job)
        underscore(job['wrapped'] || worker.class.to_s)
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
