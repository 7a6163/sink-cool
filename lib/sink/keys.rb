# frozen_string_literal: true

module Sink
  module Keys
    module_function

    def underscore(key)
      key.to_s
         .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .downcase
         .to_sym
    end

    def camelize(key)
      head, *tail = key.to_s.split("_")
      [head, *tail.map(&:capitalize)].join
    end

    # Sink payloads are flat, so nested hashes such as `geo` keep their original
    # keys (country codes) instead of being converted to snake_case.
    def underscore_keys(hash)
      hash.to_h { |key, value| [underscore(key), value] }
    end

    def camelize_keys(hash)
      hash.to_h { |key, value| [camelize(key), value] }
    end
  end
end
