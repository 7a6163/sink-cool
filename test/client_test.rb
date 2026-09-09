# frozen_string_literal: true

require "test_helper"

class SinkClientTest < Minitest::Test
  cover "Sink::Client*"
  cover "Sink::Error*"

  CREATED_LINK = {
    "link" => {
      "id" => "abc123",
      "url" => "https://example.com",
      "slug" => "example",
      "tags" => ["articles"],
      "redirectWithQuery" => true,
      "geo" => { "US" => "https://example.com/us" },
      "createdAt" => 1_700_000_000,
      "updatedAt" => 1_700_000_500,
      "expiration" => 1_800_000_000
    },
    "shortLink" => "https://sink.example/example"
  }.freeze

  def setup
    @client = Sink::Client.new(base_url: "https://sink.example/", token: "secret-token")
    @requests = []
  end

  def test_sends_authentication_and_normalizes_verify_keys
    body = '{"name":"Sink","authMethod":"site-token","userEmail":"admin@example.com"}'
    result = with_response(200, body) { @client.verify }
    request = @requests.fetch(0)

    assert_equal "site-token", result[:auth_method]
    assert_equal "admin@example.com", result[:user_email]
    assert_equal "/api/verify", request.uri.request_uri
    assert_equal "Bearer secret-token", request["Authorization"]
    assert_equal "application/json", request["Accept"]
    assert_nil request["Content-Type"]
    assert_nil request.body
  end

  def test_verify_falls_back_to_an_empty_hash
    assert_empty(with_response(204, "") { @client.verify })
  end

  def test_omits_the_query_string_when_no_filters_are_given
    with_response { @client.links }

    assert_nil @requests.fetch(0).uri.query
  end

  def test_link_endpoints
    with_response do
      @client.create_link(url: "https://example.com", slug: "example")
      @client.edit_link(url: "https://example.com", slug: "example")
      @client.upsert_link(url: "https://example.com")
      @client.delete_link("example")
      @client.link("example")
      @client.links(limit: 10, sort: "oldest")
      @client.search_links(query: "exam", status: "active")
      @client.tags
      @client.check_links(limit: 3, timeout: 10)
    end

    assert_requests(
      ["POST", "/api/link/create"],
      ["PUT", "/api/link/edit"],
      ["POST", "/api/link/upsert"],
      ["POST", "/api/link/delete"],
      ["GET", "/api/link/query"],
      ["GET", "/api/link/list"],
      ["GET", "/api/link/search"],
      ["GET", "/api/link/tags"],
      ["POST", "/api/link/check"]
    )
    assert_equal({ "slug" => "example" }, query(@requests[4]))
    assert_equal({ "limit" => "10", "sort" => "oldest" }, query(@requests[5]))
    assert_equal({ "q" => "exam", "status" => "active" }, query(@requests[6]))
    assert_equal({ "limit" => 3, "timeout" => 10 }, JSON.parse(@requests[8].body))
  end

  def test_sends_the_slug_when_deleting
    with_response(204, "") { @client.delete_link("example") }

    assert_equal({ "slug" => "example" }, JSON.parse(@requests.fetch(0).body))
    assert_equal "application/json", @requests.fetch(0)["Content-Type"]
  end

  def test_sends_url_and_slug_for_edit_and_upsert
    links = with_response(200, JSON.generate(CREATED_LINK)) do
      [
        @client.edit_link(url: "https://example.com", slug: "example", redirect_with_query: true),
        @client.upsert_link(url: "https://example.com", slug: "example", redirect_with_query: true)
      ]
    end

    expected = { "url" => "https://example.com", "slug" => "example", "redirectWithQuery" => true }

    assert_equal expected, JSON.parse(@requests.fetch(0).body)
    assert_equal expected, JSON.parse(@requests.fetch(1).body)
    links.each { |link| assert_instance_of Sink::Link, link }
  end

  def test_sends_every_list_and_search_filter
    with_response do
      @client.links(limit: 10, cursor: "c", sort: "oldest", tag: "articles", status: "active")
      @client.search_links(query: "exam", url: "https://example.com", limit: 5, tag: "articles", status: "expired")
    end

    assert_equal(
      { "limit" => "10", "cursor" => "c", "sort" => "oldest", "tag" => "articles", "status" => "active" },
      query(@requests.fetch(0))
    )
    assert_equal(
      { "q" => "exam", "url" => "https://example.com", "limit" => "5", "tag" => "articles", "status" => "expired" },
      query(@requests.fetch(1))
    )
  end

  def test_searches_without_a_query
    with_response { @client.search_links(url: "https://example.com") }

    assert_equal({ "url" => "https://example.com" }, query(@requests.fetch(0)))
  end

  def test_defaults_the_check_limit_and_timeout
    with_response { @client.check_links(cursor: "c") }

    assert_equal({ "cursor" => "c", "limit" => 6, "timeout" => 6 }, JSON.parse(@requests.fetch(0).body))
  end

  def test_camelizes_link_attributes
    with_response { @client.create_link(url: "https://example.com", redirect_with_query: true, tags: ["a"]) }

    assert_equal(
      { "url" => "https://example.com", "redirectWithQuery" => true, "tags" => ["a"] },
      JSON.parse(@requests.fetch(0).body)
    )
  end

  def test_converts_expires_at_to_unix_timestamp
    expires_at = Time.utc(2030, 1, 2, 3, 4, 5)

    with_response { @client.create_link(url: "https://example.com", expires_at: expires_at) }

    assert_equal expires_at.to_i, JSON.parse(@requests.fetch(0).body).fetch("expiration")
  end

  def test_rejects_unknown_link_attributes
    error = assert_raises(ArgumentError) do
      @client.create_link(url: "https://example.com", sulg: "typo", tsg: "typo")
    end

    assert_equal "unknown link attributes: sulg, tsg", error.message
  end

  def test_drops_nil_link_attributes
    with_response { @client.create_link(url: "https://example.com", slug: "example", comment: nil) }

    assert_equal({ "url" => "https://example.com", "slug" => "example" }, JSON.parse(@requests.fetch(0).body))
  end

  def test_requires_url_and_slug_for_edit
    assert_raises(ArgumentError) { @client.edit_link(url: "https://example.com") }
  end

  def test_returns_link_objects_for_writes
    link = with_response(201, JSON.generate(CREATED_LINK)) { @client.create_link(url: "https://example.com") }

    assert_instance_of Sink::Link, link
    assert_equal "example", link.slug
    assert_equal "https://sink.example/example", link.short_link
    assert_equal ["articles"], link.tags
    assert link.redirect_with_query?
    refute link.cloaking?
    assert_equal({ "US" => "https://example.com/us" }, link.geo)
    assert_equal Time.at(1_700_000_000).utc, link.created_at
    assert_equal Time.at(1_800_000_000).utc, link.expires_at
  end

  def test_returns_link_object_for_flat_query_response
    link = with_response(200, '{"slug":"example","url":"https://example.com"}') { @client.link("example") }

    assert_equal "example", link.slug
    assert_equal "https://sink.example/example", link.short_link
  end

  def test_derives_short_link_for_listed_links
    page = with_response(200, '{"links":[{"slug":"a"},{"slug":"b"}]}') { @client.links }

    assert_equal %w[https://sink.example/a https://sink.example/b], page.map(&:short_link)
  end

  def test_exposes_upsert_status
    body = JSON.generate(CREATED_LINK.merge("status" => "existing"))
    link = with_response(200, body) { @client.upsert_link(url: "https://example.com", slug: "example") }

    assert link.existing?
    refute link.created?
  end

  def test_returns_pages_for_collections
    body = '{"links":[{"slug":"a"},{"slug":"b"}],"cursor":"next","list_complete":false}'
    page = with_response(200, body) { @client.links }

    assert_instance_of Sink::Page, page
    assert_equal %w[a b], page.map(&:slug)
    assert_equal "next", page.cursor
    refute page.complete?
    assert page.more?
  end

  def test_search_returns_page_for_array_response
    page = with_response(200, '[{"slug":"a"}]') { @client.search_links(query: "a") }

    assert_equal %w[a], page.map(&:slug)
    assert page.complete?
    refute page.more?
  end

  def test_each_link_follows_the_cursor
    pages = [
      '{"links":[{"slug":"a"}],"cursor":"next","list_complete":false}',
      '{"links":[{"slug":"b"}],"list_complete":true}'
    ]

    slugs = with_responses(pages) { @client.each_link(limit: 1).map(&:slug) }

    assert_equal %w[a b], slugs
    assert_equal({ "limit" => "1" }, query(@requests.fetch(0)))
    assert_equal({ "limit" => "1", "cursor" => "next" }, query(@requests.fetch(1)))
  end

  def test_returns_tag_objects
    tags = with_response(200, '[{"name":"articles","count":3}]') { @client.tags }

    assert_equal "articles", tags.first.name
    assert_equal 3, tags.first.count
  end

  def test_returns_no_tags_for_an_empty_response
    assert_empty(with_response(200, "null") { @client.tags })
    assert_empty(with_response(200, "") { @client.tags })
  end

  def test_treats_a_page_without_list_complete_as_complete
    page = with_response(200, '{"links":[{"slug":"a"}],"cursor":"next"}') { @client.links }

    assert page.complete?
    refute page.more?
  end

  def test_returns_page_of_check_results
    body = '{"results":[{"slug":"a","statusCode":200}],"cursor":"next","list_complete":false}'
    page = with_response(200, body) { @client.check_links }

    assert_equal [{ slug: "a", status_code: 200 }], page.to_a
    assert_equal "next", page.cursor
  end

  def test_delete_returns_true_for_no_content
    assert with_response(204, "") { @client.delete_link("example") }
  end

  def test_raises_structured_error
    error = assert_raises(Sink::Unauthorized) do
      with_response(401, '{"statusMessage":"Unauthorized"}') { @client.verify }
    end

    assert_equal 401, error.status
    assert_equal "Unauthorized", error.message
    assert_equal({ "statusMessage" => "Unauthorized" }, error.body)
    assert_kind_of Sink::Error, error
  end

  def test_maps_status_codes_to_error_classes
    expected = {
      400 => Sink::ValidationError,
      401 => Sink::Unauthorized,
      403 => Sink::Forbidden,
      404 => Sink::NotFound,
      409 => Sink::Conflict,
      422 => Sink::ValidationError,
      423 => Sink::StorageNotReady,
      429 => Sink::RateLimited,
      500 => Sink::ServerError,
      402 => Sink::Error
    }

    expected.each do |status, klass|
      error = assert_raises(klass) { with_response(status, "{}") { @client.tags } }
      assert_equal status, error.status
    end
  end

  def test_exposes_validation_error_data
    error = assert_raises(Sink::ValidationError) do
      with_response(400, '{"statusMessage":"Bad Request","data":{"issues":[]}}') { @client.tags }
    end

    assert_equal({ "issues" => [] }, error.data)
  end

  def test_falls_back_when_message_is_only_whitespace
    body = '{"error":true,"statusCode":401,"statusMessage":"Unauthorized","message":"  "}'

    error = assert_raises(Sink::Unauthorized) { with_response(401, body) { @client.verify } }

    assert_equal "Unauthorized", error.message
  end

  def test_trims_and_skips_unusable_error_messages
    body = '{"message":false,"statusMessage":"  Unauthorized  "}'

    error = assert_raises(Sink::Unauthorized) { with_response(401, body, "Unauthorized") { @client.verify } }

    assert_equal "Unauthorized", error.message
  end

  def test_falls_back_to_the_http_status_for_non_hash_bodies
    error = assert_raises(Sink::ServerError) do
      with_response(500, "no message here", "Internal Server Error") { @client.verify }
    end

    assert_equal "HTTP 500 Internal Server Error", error.message

    empty = assert_raises(Sink::ServerError) { with_response(500, "", "Internal Server Error") { @client.verify } }

    assert_equal "HTTP 500 Internal Server Error", empty.message
  end

  def test_prefers_message_over_the_other_error_keys
    body = '{"message":"Primary","statusMessage":"Secondary","statusText":"Tertiary"}'

    error = assert_raises(Sink::NotFound) { with_response(404, body) { @client.verify } }

    assert_equal "Primary", error.message
  end

  def test_reads_status_text_error_message
    error = assert_raises(Sink::Conflict) do
      with_response(409, '{"statusText":"Link already exists"}') { @client.create_link(url: "https://example.com") }
    end

    assert_equal "Link already exists", error.message
  end

  def test_falls_back_to_http_status_without_error_message
    error = assert_raises(Sink::StorageNotReady) { with_response(423, "{}", "Locked") { @client.tags } }

    assert_equal "HTTP 423 Locked", error.message
  end

  def test_treats_an_empty_body_as_no_body
    assert_nil(with_response(200, "") { @client.link("example") })
    assert_nil(with_response(200, nil) { @client.link("example") })
  end

  def test_wraps_timeouts_and_connection_failures
    timeout = assert_raises(Sink::TimeoutError) { with_transport_error(Net::ReadTimeout.new) { @client.verify } }

    assert_equal "sink.example timed out: Net::ReadTimeout", timeout.message

    connection = assert_raises(Sink::ConnectionError) { with_transport_error(SocketError.new("no dns")) { @client.verify } }

    assert_equal "sink.example is unreachable: no dns", connection.message

    assert_kind_of Sink::Error, assert_raises(Sink::TimeoutError) { with_transport_error(Net::OpenTimeout.new) { @client.verify } }
  end

  def test_accepts_unix_expiration_and_rejects_unsupported_values
    with_response { @client.create_link(url: "https://example.com", expires_at: 1_900_000_000.9) }

    assert_equal 1_900_000_000, JSON.parse(@requests.fetch(0).body).fetch("expiration")

    error = assert_raises(ArgumentError) { @client.create_link(url: "https://example.com", expires_at: "tomorrow") }

    assert_equal "expires_at must be a Time or a unix timestamp", error.message
  end

  def test_accepts_a_date_expiration
    with_response { @client.create_link(url: "https://example.com", expires_at: Date.new(2030, 1, 2)) }

    assert_equal Date.new(2030, 1, 2).to_time.to_i, JSON.parse(@requests.fetch(0).body).fetch("expiration")
  end

  def test_returns_raw_body_when_the_response_is_not_json
    error = assert_raises(Sink::ServerError) { with_response(500, "<html>boom</html>") { @client.tags } }

    assert_equal "<html>boom</html>", error.body
    assert_match(/500/, error.message)
  end

  def test_returns_empty_page_for_unexpected_body
    page = with_response(200, '"unexpected"') { @client.links }

    assert page.empty?
    assert page.complete?
  end

  def test_rejects_invalid_configuration
    %w[ftp://sink.example http: https://sink.example/\ bad].each do |base_url|
      error = assert_raises(ArgumentError) { Sink::Client.new(base_url: base_url, token: "token") }

      assert_equal "base_url must be an HTTP(S) URL", error.message
    end

    error = assert_raises(ArgumentError) { Sink::Client.new(base_url: "https://sink.example", token: "") }

    assert_equal "token is required", error.message
  end

  def test_accepts_a_uri_base_url_and_strips_trailing_slashes
    client = Sink::Client.new(base_url: URI("https://sink.example///"), token: "secret-token")
    handler = lambda do |_uri, request|
      @requests << request
      build_response(200, '{"slug":"a"}')
    end
    link = stub_transport(handler, client) { client.link("a") }

    assert_equal "https://sink.example/a", link.short_link
    assert_equal "https://sink.example/api/link/query?slug=a", @requests.fetch(0).uri.to_s
  end

  def test_stringifies_the_token
    client = Sink::Client.new(base_url: "https://sink.example", token: 12_345)
    handler = lambda do |_uri, request|
      @requests << request
      build_response(200, "{}")
    end
    stub_transport(handler, client) { client.verify }

    assert_equal "Bearer 12345", @requests.fetch(0)["Authorization"]
  end

  def test_applies_the_default_timeouts
    assert_equal 5, @client.instance_variable_get(:@open_timeout)
    assert_equal 30, @client.instance_variable_get(:@read_timeout)
  end

  private

  def with_response(status = 200, body = "{}", message = nil, &)
    with_responses([[status, body, message]], &)
  end

  def with_responses(responses, &)
    queue = responses.map { |response| response.is_a?(Array) ? response : [200, response] }
                     .map { |status, body, message| build_response(status, body, message) }

    stub_transport(->(_uri, request) {
      @requests << request
      queue.length > 1 ? queue.shift : queue.first
    }, &)
  end

  def with_transport_error(error, &)
    stub_transport(->(_uri, _request) { raise error }, &)
  end

  def stub_transport(handler, client = @client)
    singleton = client.singleton_class
    singleton.define_method(:perform_request) { |uri, request| handler.call(uri, request) }

    yield
  ensure
    singleton&.remove_method(:perform_request)
  end

  def build_response(status, body, message = nil)
    response_class = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s)
    response = response_class.new("1.1", status.to_s, message)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def assert_requests(*expected)
    actual = @requests.map { |request| [request.method, request.uri.path] }
    assert_equal expected, actual
  end

  def query(request)
    URI.decode_www_form(request.uri.query).to_h
  end
end
