# frozen_string_literal: true

require_relative "lib/sink/version"

Gem::Specification.new do |spec|
  spec.name = "sink-cool"
  spec.version = Sink::VERSION
  spec.authors = ["Sink Ruby contributors"]
  spec.summary = "Ruby client for the Sink URL shortener API"
  spec.description = "A lightweight Ruby client for managing links with the Sink URL shortener API."
  spec.homepage = "https://docs.sink.cool/api/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/7a6163/sink-cool",
    "changelog_uri" => "https://github.com/7a6163/sink-cool/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb"] + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
