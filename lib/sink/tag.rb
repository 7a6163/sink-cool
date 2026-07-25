# frozen_string_literal: true

module Sink
  Tag = Data.define(:name, :count) do
    def self.from_response(body)
      return new(name: body.to_s, count: nil) unless body.is_a?(Hash)

      new(name: body["name"], count: body["count"])
    end

    def to_s = name.to_s
  end
end
