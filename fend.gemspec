require File.expand_path("../lib/fend/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name         = "fend"
  gem.version      = Fend.version
  gem.authors      = ["Aleksandar Radunovic"]
  gem.email        = ["a.radunovic@pm.me"]

  gem.summary      = "Small and extensible data validation toolkit"
  gem.description  = gem.summary
  gem.homepage     = "https://aradunovic.github.io/fend"
  gem.license      = "MIT"

  gem.files        = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "fend.gemspec", "doc/*.md"]
  gem.require_path = "lib"

  gem.required_ruby_version = ">= 2.0"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
end
