# frozen_string_literal: true

require_relative "lib/sink/version"

Gem::Specification.new do |spec|
  spec.name = "sink-cool"
  spec.version = Sink::VERSION
  spec.authors = ["Sink Ruby contributors"]
  spec.summary = "Ruby client for the Sink URL shortener API"
  spec.homepage = "https://docs.sink.cool/api/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb"] + %w[README.md CHANGELOG.md]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
