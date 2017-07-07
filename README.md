sidekiq-datadog
=============

Datadog intrumentation for [Sidekiq](https://github.com/mperham/sidekiq), integrated via server middleware.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-datadog'

Or install:

    $ gem install sidekiq-datadog

Configure it in an initializer:

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add Sidekiq::Middleware::Server::Datadog
      end
    end

## Options

Options can be configured to be passed to the middleware constructor when it is added to the
chain

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add(Sidekiq::Middleware::Server::Datadog, statsd_port: 3334)
      end
    end

Custom tags can be configured using the `tags:` property

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add(Sidekiq::Middleware::Server::Datadog, tags: ['runtime:jruby'])
      end
    end

Dynamic tags can be configured by passing a lambda in the tags array. It is
executed at runtime when the job is processed

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add(Sidekiq::Middleware::Server::Datadog, tags: [->(worker, job, queue, error){
          "source:#{job['source']}"
        }])
      end
    end

#### supported options
 - *hostname* - the hostname used for instrumentation, defaults to system hostname. Can also be set with the `INSTRUMENTATION_HOSTNAME` env var.
 - *metric_name* - the metric name (prefix) to use, defaults to "sidekiq.job".
 - *tags* - array of custom tags. These can be plain strings or lambda blocks
 - *statsd_host* - the statsD host, defaults to "localhost". Can also be set with the `STATSD_HOST` env var
 - *statsd_port* - the statsD port, defaults to 8125. Can also be set with the `STATSD_PORT` env var
 - *statsd* - custom statsd instance

For more detailed configuration options, please see the [Documentation](http://www.rubydoc.info/gems/sidekiq-datadog).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make a pull request

