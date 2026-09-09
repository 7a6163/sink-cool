# frozen_string_literal: true

module Sink
  class Error < StandardError
    attr_reader :status, :body

    def self.for(status:, message:, body: nil)
      klass = STATUS_ERRORS[status] || (status >= 500 ? ServerError : self)
      klass.new(message, status: status, body: body)
    end

    def initialize(message = nil, status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end

    def data = body.is_a?(Hash) ? body["data"] : nil
  end

  class ValidationError < Error; end
  class Unauthorized < Error; end
  class Forbidden < Error; end
  class NotFound < Error; end
  class Conflict < Error; end
  class StorageNotReady < Error; end
  class RateLimited < Error; end
  class ServerError < Error; end
  class ConnectionError < Error; end
  class TimeoutError < ConnectionError; end

  class Error
    STATUS_ERRORS = {
      400 => ValidationError,
      401 => Unauthorized,
      403 => Forbidden,
      404 => NotFound,
      409 => Conflict,
      422 => ValidationError,
      423 => StorageNotReady,
      429 => RateLimited
    }.freeze
  end
end
