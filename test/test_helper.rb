# frozen_string_literal: true

# Mutant forks per mutation, so coverage reports would fight over coverage/.
unless defined?(Mutant)
  require "simplecov"
  require "simplecov_json_formatter"

  SimpleCov.start do
    add_filter "/test/"
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter
    ])
  end
end

require "minitest/autorun"
require "mutant/minitest/coverage"
require "sink"
