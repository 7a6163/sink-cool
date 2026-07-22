# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Sink
  class Client
    REQUEST_CLASSES = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put
    }.freeze

    def initialize(base_url:, token:, open_timeout: 5, read_timeout: 30)
      @base_url = validate_base_url(base_url)
      @token = token.to_s
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      raise ArgumentError, "token is required" if @token.empty?
    end

    def verify = request(:get, "/api/verify")

    def create_link(attributes) = request(:post, "/api/link/create", body: attributes)

    def edit_link(attributes) = request(:put, "/api/link/edit", body: attributes)

    def upsert_link(attributes) = request(:post, "/api/link/upsert", body: attributes)

    def delete_link(slug) = request(:post, "/api/link/delete", body: { slug: slug })

    def link(slug) = request(:get, "/api/link/query", query: { slug: slug })

    def links(limit: nil, cursor: nil, sort: nil, tag: nil, status: nil)
      request(:get, "/api/link/list", query: {
        limit: limit, cursor: cursor, sort: sort, tag: tag, status: status
      })
    end

    def search_links(query: nil, url: nil, limit: nil, tag: nil, status: nil)
      request(:get, "/api/link/search", query: {
        q: query, url: url, limit: limit, tag: tag, status: status
      })
    end

    def tags = request(:get, "/api/link/tags")

    def check_links(cursor: nil, limit: 6, timeout: 6)
      request(:post, "/api/link/check", body: {
        cursor: cursor, limit: limit, timeout: timeout
      }.compact)
    end

    private

    def request(method, path, query: nil, body: nil)
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(query.compact) if query&.compact&.any?

      headers = {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/json",
        "User-Agent" => "sink-cool/#{Sink::VERSION}"
      }
      headers["Content-Type"] = "application/json" if body

      http_request = REQUEST_CLASSES.fetch(method).new(uri, headers)
      http_request.body = JSON.generate(body) if body

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @open_timeout,
        read_timeout: @read_timeout
      ) { |http| http.request(http_request) }

      parse_response(response)
    end

    def parse_response(response)
      return nil if response.code.to_i == 204

      body = parse_body(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      message = if body.is_a?(Hash)
                  body["message"] || body["statusMessage"]
                end
      message ||= "HTTP #{response.code} #{response.message}"
      raise Error.new(status: response.code.to_i, message: message, body: body)
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def validate_base_url(base_url)
      uri = URI(base_url.to_s)
      raise ArgumentError, "base_url must be an HTTP(S) URL" unless %w[http https].include?(uri.scheme) && uri.host

      base_url.to_s.sub(%r{/+\z}, "")
    rescue URI::InvalidURIError
      raise ArgumentError, "base_url must be an HTTP(S) URL"
    end
  end
end
