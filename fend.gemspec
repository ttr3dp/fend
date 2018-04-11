require File.expand_path("../lib/fend/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fend"
  gem.version       = Fend.version
  gem.authors       = ["Aleksandar Radunovic"]
  gem.email         = ["aleksandar@radunovic.io"]

  gem.summary       = "Small and extensible data validation toolkit"
  gem.description   = gem.summary
  gem.homepage      = "https://fend.radunovic.io"
  gem.license       = "MIT"

  gem.files         = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "fend.gemspec"]
  gem.require_path = "lib"

  gem.add_development_dependency "rake", "~> 10.0"

  gem.add_development_dependency "rspec", "~> 3.0"
end
