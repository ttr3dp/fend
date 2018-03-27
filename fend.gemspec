require File.expand_path("../lib/fend/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fend"
  gem.version       = Fend::VERSION
  gem.authors       = ["Aleksandar Radunovic"]
  gem.email         = ["aleksandar@radunovic.io"]

  gem.summary       = "Pending"
  gem.description   = "Pending"
  gem.homepage      = "https://pending.com"
  gem.license       = "MIT"

  gem.files         = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "fend.gemspec"]
  gem.require_path = "lib"

  gem.add_development_dependency "bundler", "~> 1.16"
  gem.add_development_dependency "rake", "~> 10.0"

  gem.add_development_dependency "rspec", "~> 3.0"
end
