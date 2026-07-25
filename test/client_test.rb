# frozen_string_literal: true

require "test_helper"

class SinkClientTest < Minitest::Test
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
    error = assert_raises(ArgumentError) { @client.create_link(url: "https://example.com", sulg: "typo") }

    assert_match(/sulg/, error.message)
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
    assert_nil link.short_link
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

  def test_falls_back_when_message_is_blank
    body = '{"error":true,"statusCode":401,"statusMessage":"Unauthorized","message":""}'

    error = assert_raises(Sink::Unauthorized) { with_response(401, body) { @client.verify } }

    assert_equal "Unauthorized", error.message
  end

  def test_reads_status_text_error_message
    error = assert_raises(Sink::Conflict) do
      with_response(409, '{"statusText":"Link already exists"}') { @client.create_link(url: "https://example.com") }
    end

    assert_equal "Link already exists", error.message
  end

  def test_falls_back_to_http_status_without_error_message
    error = assert_raises(Sink::StorageNotReady) { with_response(423, "{}") { @client.tags } }

    assert_match(/423/, error.message)
  end

  def test_wraps_timeouts_and_connection_failures
    assert_raises(Sink::TimeoutError) { with_transport_error(Net::ReadTimeout.new) { @client.verify } }
    assert_raises(Sink::ConnectionError) { with_transport_error(SocketError.new("no dns")) { @client.verify } }
    assert_kind_of Sink::Error, assert_raises(Sink::TimeoutError) { with_transport_error(Net::OpenTimeout.new) { @client.verify } }
  end

  def test_accepts_unix_expiration_and_rejects_unsupported_values
    with_response { @client.create_link(url: "https://example.com", expires_at: 1_900_000_000) }

    assert_equal 1_900_000_000, JSON.parse(@requests.fetch(0).body).fetch("expiration")
    assert_raises(ArgumentError) { @client.create_link(url: "https://example.com", expires_at: "tomorrow") }
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
    assert_raises(ArgumentError) { Sink::Client.new(base_url: "ftp://sink.example", token: "token") }
    assert_raises(ArgumentError) { Sink::Client.new(base_url: "https://sink.example", token: "") }
    assert_raises(ArgumentError) { Sink::Client.new(base_url: "https://sink.example/ bad", token: "token") }
  end

  private

  def with_response(status = 200, body = "{}", &)
    with_responses([[status, body]], &)
  end

  def with_responses(responses, &)
    queue = responses.map { |response| response.is_a?(Array) ? response : [200, response] }
                     .map { |status, body| build_response(status, body) }

    stub_transport(->(_uri, request) {
      @requests << request
      queue.length > 1 ? queue.shift : queue.first
    }, &)
  end

  def with_transport_error(error, &)
    stub_transport(->(_uri, _request) { raise error }, &)
  end

  def stub_transport(handler)
    singleton = @client.singleton_class
    singleton.define_method(:perform_request) { |uri, request| handler.call(uri, request) }

    yield
  ensure
    singleton&.remove_method(:perform_request)
  end

  def build_response(status, body)
    response_class = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s)
    response = response_class.new("1.1", status.to_s, nil)
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
