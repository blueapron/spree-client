lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'blue_apron/spree_client/version'

Gem::Specification.new do |s|
  s.name        = 'Blue Apron Spree Client'
  s.version     = BlueApron::SpreeClient::VERSION
  s.licenses    = ['MIT']
  s.summary     = "A simple ruby client to interact with the Spree API."
  s.description = "A simple ruby client to interact with the Spree API."
  s.authors     = ["Blue Apron Engineering"]
  s.email       = 'engineering@blueapron.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.homepage    = 'https://github.com/blueapron/spree-client'

  s.add_dependency              "faraday"
  s.add_dependency              "json"
  s.add_dependency              "hashie"

  s.add_development_dependency  "rspec"
  s.add_development_dependency  "rake"
end
