# frozen_string_literal: true

require "test_helper"

class SinkErrorTest < Minitest::Test
  cover "Sink::Error*"

  def test_maps_known_status_codes
    Sink::Error::STATUS_ERRORS.each do |status, klass|
      assert_instance_of klass, Sink::Error.for(status: status, message: "boom")
    end
  end

  def test_maps_every_server_status_code
    assert_instance_of Sink::ServerError, Sink::Error.for(status: 500, message: "boom")
    assert_instance_of Sink::ServerError, Sink::Error.for(status: 503, message: "boom")
  end

  def test_falls_back_to_the_base_error_below_500
    assert_instance_of Sink::Error, Sink::Error.for(status: 402, message: "boom")
    assert_instance_of Sink::Error, Sink::Error.for(status: 499, message: "boom")
  end

  def test_carries_status_message_and_body
    error = Sink::Error.for(status: 404, message: "Not Found", body: { "message" => "Not Found" })

    assert_equal 404, error.status
    assert_equal "Not Found", error.message
    assert_equal({ "message" => "Not Found" }, error.body)
  end

  def test_defaults_the_body_to_nil
    error = Sink::Error.for(status: 404, message: "Not Found")

    assert_nil error.body
    assert_nil error.data
  end

  def test_reads_data_only_from_hash_bodies
    assert_equal({ "issues" => [] }, Sink::Error.new(body: { "data" => { "issues" => [] } }).data)
    assert_nil Sink::Error.new(body: { "message" => "no data" }).data
    assert_nil Sink::Error.new(body: "<html>invalid data</html>").data
    assert_nil Sink::Error.new(body: ["data"]).data
  end

  def test_builds_without_arguments
    error = Sink::Error.new

    assert_nil error.status
    assert_nil error.body
    assert_equal "Sink::Error", error.message
  end
end
