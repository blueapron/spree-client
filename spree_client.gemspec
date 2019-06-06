# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'blue_apron/spree_client/version'

Gem::Specification.new do |s|
  s.name        = 'spree_client'
  s.version     = BlueApron::SpreeClient::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Blue Apron Ruby Spree Client'
  s.description = 'A simple ruby client to interact with the Spree API.'
  s.authors     = ['Blue Apron Engineering']
  s.email       = 'engineering@blueapron.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.homepage    = 'https://github.com/blueapron/spree-client'

  s.add_dependency 'faraday'
  s.add_dependency 'hashie'
  s.add_dependency 'json'
  s.add_dependency 'sanitize'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end
