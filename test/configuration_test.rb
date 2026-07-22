# frozen_string_literal: true

require "minitest/autorun"
require "sink"

class SinkConfigurationTest < Minitest::Test
  def setup
    Sink.configure do |config|
      config.base_url = "https://sink.example"
      config.token = "secret-token"
    end
  end

  def test_configures_and_reuses_a_client
    client = Sink.client

    assert_instance_of Sink::Client, client
    assert_same client, Sink.client
  end

  def test_rebuilds_the_client_after_reconfiguration
    previous_client = Sink.client

    Sink.configure do |config|
      config.base_url = "https://other.example"
      config.token = "other-token"
    end

    refute_same previous_client, Sink.client
  end
end
