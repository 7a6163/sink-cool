# frozen_string_literal: true

require "test_helper"
require "socket"

# The rest of the suite stubs `perform_request`, so this is the only place the
# real Net::HTTP call is exercised. It talks to a throwaway TCP server instead
# of the network.
class SinkTransportTest < Minitest::Test
  cover "Sink::Client#perform_request"

  def teardown
    @server&.close
    @thread&.kill
  end

  def test_sends_a_real_request_and_reads_the_response
    headers = serve("HTTP/1.1 200 OK\r\nContent-Length: 15\r\n\r\n{\"name\":\"Sink\"}")

    assert_equal({ name: "Sink" }, client.verify)
    assert_match(%r{\AGET /api/verify HTTP/1\.1\r\n}, headers.value)
    assert_match(/^Authorization: Bearer secret-token\r$/, headers.value)
    assert_match(%r{^User-Agent: sink-cool/#{Regexp.escape(Sink::VERSION)}\r$}, headers.value)
  end

  def test_sends_a_json_body_for_writes
    headers = serve("HTTP/1.1 204 No Content\r\n\r\n")

    assert client.delete_link("example")
    assert_match(%r{\APOST /api/link/delete HTTP/1\.1\r\n}, headers.value)
    assert_match(/^Content-Type: application\/json\r$/, headers.value)
  end

  def test_raises_a_timeout_error_when_the_server_never_answers
    serve(nil)

    assert_raises(Sink::TimeoutError) { client(read_timeout: 0.2).verify }
  end

  def test_raises_a_connection_error_when_nothing_is_listening
    port = with_closed_port

    assert_raises(Sink::ConnectionError) do
      Sink::Client.new(base_url: "http://127.0.0.1:#{port}", token: "secret-token").verify
    end
  end

  private

  # Answers one request with `response`, or hangs when it is nil, and returns a
  # thread whose value is the request head the client sent.
  def serve(response)
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new do
      socket = @server.accept
      head = socket.gets("\r\n\r\n")
      next head unless response

      socket.print(response)
      socket.close
      head
    end
  end

  def client(**options)
    Sink::Client.new(base_url: "http://127.0.0.1:#{@server.addr[1]}", token: "secret-token", **options)
  end

  def with_closed_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end
end
