# frozen_string_literal: true

module Sink
  class Error < StandardError
    attr_reader :status, :body

    def initialize(status:, message:, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end
end
