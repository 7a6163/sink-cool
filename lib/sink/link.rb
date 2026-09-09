# frozen_string_literal: true

module Sink
  class Link
    ATTRIBUTES = %i[
      id url slug comment title description image apple google password
      cloaking redirect_with_query unsafe geo tags expiration
      created_at updated_at short_link status
    ].freeze

    attr_reader :attributes

    # The API only builds `shortLink` for write endpoints, from the protocol and
    # host of the request, so `base_url` reproduces it for the read endpoints.
    def self.from_response(body, base_url: nil)
      return nil unless body.is_a?(Hash)

      link = body["link"].is_a?(Hash) ? body["link"] : body
      attributes = Keys.underscore_keys(link)
      attributes[:status] = body["status"]
      attributes[:short_link] = body["shortLink"] ||
                                (base_url && attributes[:slug] && "#{base_url}/#{attributes[:slug]}")

      new(attributes.compact)
    end

    def initialize(attributes)
      @attributes = attributes.freeze
    end

    %i[id url slug comment title description image apple google password short_link status expiration].each do |name|
      define_method(name) { @attributes[name] }
    end

    def tags = @attributes[:tags] || []

    def geo = @attributes[:geo] || {}

    def created_at = time(:created_at)

    def updated_at = time(:updated_at)

    def expires_at = time(:expiration)

    def cloaking? = !!@attributes[:cloaking]

    def unsafe? = !!@attributes[:unsafe]

    def redirect_with_query? = !!@attributes[:redirect_with_query]

    def expired? = !expiration.nil? && expiration <= Time.now.to_i

    def created? = status == "created"

    def existing? = status == "existing"

    def [](key) = @attributes[key.to_sym]

    def to_h = @attributes.dup

    def as_json(*) = to_h

    def ==(other) = other.is_a?(Link) && other.attributes == @attributes
    alias eql? ==

    def hash = @attributes.hash

    def inspect = "#<#{self.class} slug=#{slug.inspect} url=#{url.inspect}>"

    private

    def time(key)
      value = @attributes[key]
      Time.at(value).utc if value
    end
  end
end
