# frozen_string_literal: true

require "minitest/autorun"
require "sink"

class SinkClientTest < Minitest::Test
  def setup
    @client = Sink::Client.new(base_url: "https://sink.example/", token: "secret-token")
    @requests = []
  end

  def test_sends_authentication_and_parses_json
    result = with_response(200, '{"name":"Sink"}') { @client.verify }
    request = @requests.fetch(0)

    assert_equal({ "name" => "Sink" }, result)
    assert_equal "GET", request.method
    assert_equal "/api/verify", request.uri.request_uri
    assert_equal "Bearer secret-token", request["Authorization"]
  end

  def test_link_endpoints
    attributes = { url: "https://example.com", slug: "example" }

    with_response do
      @client.create_link(attributes)
      @client.edit_link(attributes)
      @client.upsert_link(attributes)
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

  def test_returns_nil_for_no_content
    assert_nil with_response(204, "") { @client.delete_link("example") }
  end

  def test_raises_structured_error
    error = assert_raises(Sink::Error) do
      with_response(401, '{"statusMessage":"Unauthorized"}') { @client.verify }
    end

    assert_equal 401, error.status
    assert_equal "Unauthorized", error.message
    assert_equal({ "statusMessage" => "Unauthorized" }, error.body)
  end

  def test_rejects_invalid_configuration
    assert_raises(ArgumentError) { Sink::Client.new(base_url: "ftp://sink.example", token: "token") }
    assert_raises(ArgumentError) { Sink::Client.new(base_url: "https://sink.example", token: "") }
  end

  private

  def with_response(status = 200, body = "{}")
    response_class = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s)
    response = response_class.new("1.1", status.to_s, nil)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)

    requests = @requests
    singleton = @client.singleton_class
    singleton.define_method(:perform_request) do |_uri, request|
      requests << request
      response
    end

    yield
  ensure
    singleton&.remove_method(:perform_request)
  end

  def assert_requests(*expected)
    actual = @requests.map { |request| [request.method, request.uri.path] }
    assert_equal expected, actual
  end

  def query(request)
    URI.decode_www_form(request.uri.query).to_h
  end
end
