# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Sink
  class Client
    REQUEST_CLASSES = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put
    }.freeze

    LINK_ATTRIBUTES = %i[
      url slug comment expiration expires_at title description image apple google
      cloaking redirect_with_query password unsafe geo tags
    ].freeze

    TIMEOUT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error].freeze
    CONNECTION_ERRORS = [
      IOError, SocketError, SystemCallError, Net::ProtocolError, OpenSSL::SSL::SSLError
    ].freeze

    def initialize(base_url:, token:, open_timeout: 5, read_timeout: 30)
      @token = token.to_s
      raise ArgumentError, "token is required" if @token.empty?

      @base_url = validate_base_url(base_url)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def verify = Keys.underscore_keys(request(:get, "/api/verify") || {})

    def create_link(url:, **attributes)
      Link.from_response(request(:post, "/api/link/create", body: link_payload(attributes.merge(url: url))))
    end

    def edit_link(url:, slug:, **attributes)
      Link.from_response(request(:put, "/api/link/edit", body: link_payload(attributes.merge(url: url, slug: slug))))
    end

    def upsert_link(url:, **attributes)
      Link.from_response(request(:post, "/api/link/upsert", body: link_payload(attributes.merge(url: url))))
    end

    def delete_link(slug)
      request(:post, "/api/link/delete", body: { "slug" => slug })
      true
    end

    def link(slug) = Link.from_response(request(:get, "/api/link/query", query: { slug: slug }))

    def links(limit: nil, cursor: nil, sort: nil, tag: nil, status: nil)
      body = request(:get, "/api/link/list", query: {
        limit: limit, cursor: cursor, sort: sort, tag: tag, status: status
      })

      link_page(body)
    end

    def each_link(**options)
      return enum_for(:each_link, **options) unless block_given?

      cursor = nil
      loop do
        page = links(**options, cursor: cursor)
        page.each { |link| yield link }
        break unless page.more?

        cursor = page.cursor
      end
    end

    def search_links(query: nil, url: nil, limit: nil, tag: nil, status: nil)
      body = request(:get, "/api/link/search", query: {
        q: query, url: url, limit: limit, tag: tag, status: status
      })

      link_page(body)
    end

    def tags
      Array(request(:get, "/api/link/tags")).map { |tag| Tag.from_response(tag) }
    end

    def check_links(cursor: nil, limit: 6, timeout: 6)
      body = request(:post, "/api/link/check", body: {
        "cursor" => cursor, "limit" => limit, "timeout" => timeout
      }.compact)

      page(body, "results") { |result| Keys.underscore_keys(result) }
    end

    private

    def link_payload(attributes)
      unknown = attributes.keys - LINK_ATTRIBUTES
      raise ArgumentError, "unknown link attributes: #{unknown.join(", ")}" if unknown.any?

      payload = attributes.compact
      expires_at = payload.delete(:expires_at)
      payload[:expiration] = unix_timestamp(expires_at) unless expires_at.nil?

      Keys.camelize_keys(payload)
    end

    def unix_timestamp(value)
      return value.to_i if value.is_a?(Numeric)
      return value.to_time.to_i if value.respond_to?(:to_time)

      raise ArgumentError, "expires_at must be a Time or a unix timestamp"
    end

    def link_page(body) = page(body, "links") { |link| Link.from_response(link) }

    def page(body, key, &build)
      records, cursor, complete = case body
                                  when Array then [body, nil, true]
                                  when Hash then [Array(body[key]), body["cursor"], body.fetch("list_complete", true)]
                                  else [[], nil, true]
                                  end

      Page.new(records: records.map(&build), cursor: cursor, complete: complete)
    end

    def request(method, path, query: nil, body: nil)
      uri = URI("#{@base_url}#{path}")
      params = query&.compact
      uri.query = URI.encode_www_form(params) if params&.any?

      headers = {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/json",
        "User-Agent" => "sink-cool/#{Sink::VERSION}"
      }
      headers["Content-Type"] = "application/json" if body

      http_request = REQUEST_CLASSES.fetch(method).new(uri, headers)
      http_request.body = JSON.generate(body) if body

      parse_response(dispatch(uri, http_request))
    end

    def dispatch(uri, http_request)
      perform_request(uri, http_request)
    rescue *TIMEOUT_ERRORS => error
      raise TimeoutError.new("#{uri.host} timed out: #{error.message}")
    rescue *CONNECTION_ERRORS => error
      raise ConnectionError.new("#{uri.host} is unreachable: #{error.message}")
    end

    def perform_request(uri, request)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @open_timeout,
        read_timeout: @read_timeout
      ) { |http| http.request(request) }
    end

    def parse_response(response)
      return nil if response.code.to_i == 204

      body = parse_body(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      message = error_message(body) || "HTTP #{response.code} #{response.message}"
      raise Error.for(status: response.code.to_i, message: message, body: body)
    end

    def error_message(body)
      return nil unless body.is_a?(Hash)

      %w[message statusMessage statusText].filter_map { |key| body[key] }
                                         .map { |value| value.to_s.strip }
                                         .find { |value| !value.empty? }
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
