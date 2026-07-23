# frozen_string_literal: true

require_relative "sink/version"
require_relative "sink/error"
require_relative "sink/client"
require "thread"

module Sink
  Configuration = Struct.new(:base_url, :token, :open_timeout, :read_timeout, keyword_init: true)
  CLIENT_MUTEX = Mutex.new

  class << self
    def configure
      configured = configuration.dup
      yield configured

      CLIENT_MUTEX.synchronize do
        @configuration = configured
        @client = nil
      end

      configured
    end

    def configuration
      return @configuration if @configuration

      CLIENT_MUTEX.synchronize do
        @configuration ||= Configuration.new(open_timeout: 5, read_timeout: 30)
      end
    end

    def client
      return @client if @client

      CLIENT_MUTEX.synchronize { @client ||= Client.new(**configuration.to_h) }
    end
  end
end
