# frozen_string_literal: true

require "test_helper"

class SinkConfigurationTest < Minitest::Test
  def setup
    Sink.configure do |config|
      config.base_url = "https://sink.example"
      config.token = "secret-token"
      config.open_timeout = 5
      config.read_timeout = 30
    end
  end

  def test_configures_and_reuses_a_client
    client = Sink.client

    assert_instance_of Sink::Client, client
    assert_same client, Sink.client
  end

  def test_configure_returns_the_configuration
    configured = Sink.configure { |config| config.read_timeout = 10 }

    assert_same configured, Sink.configuration
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
