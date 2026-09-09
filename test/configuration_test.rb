# frozen_string_literal: true

require "test_helper"

class SinkConfigurationTest < Minitest::Test
  cover "Sink.configure"
  cover "Sink.configuration"
  cover "Sink.client"

  def setup
    Sink.configure do |config|
      config.base_url = "https://sink.example"
      config.token = "secret-token"
      config.open_timeout = 5
      config.read_timeout = 30
    end
  end

  def test_defaults_the_timeouts_and_leaves_credentials_unset
    reset_configuration

    assert_equal 5, Sink.configuration.open_timeout
    assert_equal 30, Sink.configuration.read_timeout
    assert_nil Sink.configuration.base_url
    assert_nil Sink.configuration.token
  end

  def test_configures_and_reuses_a_client
    client = Sink.client

    assert_instance_of Sink::Client, client
    assert_same client, Sink.client
  end

  def test_applies_changes_only_after_the_block_finishes
    Sink.configure do |config|
      config.token = "new-token"

      assert_equal "secret-token", Sink.configuration.token
    end

    assert_equal "new-token", Sink.configuration.token
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

  private

  def reset_configuration
    Sink.remove_instance_variable(:@configuration) if Sink.instance_variable_defined?(:@configuration)
    Sink.remove_instance_variable(:@client) if Sink.instance_variable_defined?(:@client)
  end
end
