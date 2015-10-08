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

For full configuration options, please see the [Documentation](http://www.rubydoc.info/gems/sidekiq-datadog).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make a pull request

