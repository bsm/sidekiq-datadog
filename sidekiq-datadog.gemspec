# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/datadog/version'

Gem::Specification.new do |s|
  s.name          = "sidekiq-datadog"
  s.version       = Sidekiq::Datadog::VERSION.dup
  s.authors       = ["Dimitrij Denissenko"]
  s.email         = ["dimitrij@blacksquaremedia.com"]
  s.description   = %q{Datadog metrics for sidekiq}
  s.summary       = %q{Datadog metrics for sidekiq}
  s.homepage      = "https://github.com/bsm/sidekiq-datadog"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(spec)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency(%q<sidekiq>)
  s.add_runtime_dependency(%q<dogstatsd-ruby>, "~> 2.0.0")

  s.add_development_dependency(%q<rake>)
  s.add_development_dependency(%q<bundler>)
  s.add_development_dependency(%q<rspec>, "~> 3.0")
end
