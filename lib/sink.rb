# frozen_string_literal: true

require_relative "sink/version"
require_relative "sink/error"
require_relative "sink/client"

module Sink
  Configuration = Struct.new(:base_url, :token, :open_timeout, :read_timeout, keyword_init: true)

  class << self
    def configure
      yield configuration
      @client = nil
    end

    def configuration
      @configuration ||= Configuration.new(open_timeout: 5, read_timeout: 30)
    end

    def client
      @client ||= Client.new(**configuration.to_h)
    end
  end
end
