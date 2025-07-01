# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'fluent-plugin-geoip-kk'
  spec.version       = '1.0.3'
  spec.authors       = ['kevin197011']
  spec.email         = ['kevin197011@outlook.com']
  spec.homepage      = 'https://github.com/kevin197011/fluent-plugin-geoip-kk'
  spec.summary       = 'Fluentd filter plugin to add geoip'
  spec.description   = 'A Fluentd filter plugin that adds GeoIP information to records. Supports both legacy GeoIP and GeoIP2 databases, with LRU caching for improved performance.'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'fluentd', ['>= 0.14.0', '< 2']
  spec.add_runtime_dependency 'geoip', '~> 0.1', '>= 0.1.22'
  spec.add_runtime_dependency 'lru_redux', '~> 1.0', '>= 1.0.0'
  spec.add_runtime_dependency 'maxminddb', '~> 1.5', '>= 1.5.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'test-unit', '~> 3.0' if defined?(RUBY_VERSION) && RUBY_VERSION > '2.2'

  spec.required_ruby_version = '>= 2.1.0'
end
