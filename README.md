sidekiq-datadog
=============

Datadog instrumentation for [Sidekiq](https://github.com/mperham/sidekiq), integrated via server middleware.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-datadog'

Or install:

    $ gem install sidekiq-datadog

Configure it in an initializer:

    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.add Sidekiq::Middleware::Client::Datadog
      end
    end

    Sidekiq.configure_server do |config|
      config.client_middleware do |chain|
        chain.add Sidekiq::Middleware::Client::Datadog
      end

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
        chain.add(Sidekiq::Middleware::Server::Datadog, tags: [->(worker_or_worker_class, job, queue, error){
          "source:#{job['source']}"
        }])
      end
    end

    # NOTE: Your lambda will either receive a `Worker` object for the Server middleware, 
    # or a String with the `worker_class` for the Client middleware. 
    # If you are using that argument, your lambda should be able to handle both cases.

You can supress some of the default tags from being emitted by passing in `skip_tags`. 
This is also useful if you would like to change one of the default tags, you can define
a custom lambda **and** define it as `skip_tags`


    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add(Sidekiq::Middleware::Server::Datadog,
            skip_tags: ["name"], 
            tags: [->(worker_or_worker_class, job, queue, error){
                "name:#{ my_logic_for_name }"
            }])
      end
    end


#### supported options

Both Client and Server middlewares support the same options:

 - *hostname* - the hostname used for instrumentation, defaults to system hostname. Can also be set with the `INSTRUMENTATION_HOSTNAME` env var.
 - *metric_name* - the metric name (prefix) to use, defaults to "sidekiq.job".
 - *tags* - array of custom tags. These can be plain strings or lambda blocks.
 - *skip_tags* - array of tag names that shouldn't be emitted.
 - *statsd_host* - the statsD host, defaults to "localhost". Can also be set with the `STATSD_HOST` env var
 - *statsd_port* - the statsD port, defaults to 8125. Can also be set with the `STATSD_PORT` env var
 - *statsd* - custom statsd instance

For more detailed configuration options, please see the [Documentation](http://www.rubydoc.info/gems/sidekiq-datadog).

## Metrics exposed

The client middleware will expose:
- `sidekiq.job_enqueued` counter, with tags: `host`, `env`, `name` (the job name) and `queue`

The server middleware will expose:
- `sidekiq.job` counter, with tags: `host`, `env`, `name` (the job name), `queue`, 
    and `status` (`ok` or `error`). If `status` is `error`, there will be an additional
    `error` tag with the exception class.
- `sidekiq.job.time` timing (`ms`) metric with the same tags, specifying the job runtime.
- `sidekiq.job.queued_time` timing (`ms`) metric with the same tags, specifying how long
    the job was waiting in the queue before starting.

The base metric names `sidekiq.job` and `sidekiq.job_enqueued` can be overriden using the
`metric_name` option.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make a pull request

