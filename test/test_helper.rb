# frozen_string_literal: true

require "simplecov"
require "simplecov_json_formatter"

SimpleCov.start do
  add_filter "/test/"
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
end

require "minitest/autorun"
require "sink"
