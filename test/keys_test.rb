# frozen_string_literal: true

require "test_helper"

class SinkKeysTest < Minitest::Test
  cover "Sink::Keys*"

  def test_underscores_camel_case
    assert_equal :redirect_with_query, Sink::Keys.underscore("redirectWithQuery")
    assert_equal :user_id, Sink::Keys.underscore("userID")
    assert_equal :list_complete, Sink::Keys.underscore("list_complete")
  end

  def test_underscores_every_acronym_boundary
    assert_equal :api_key_xml_data, Sink::Keys.underscore("APIKeyXMLData")
  end

  def test_underscores_digit_boundaries_only_before_capitals
    assert_equal :v2_url, Sink::Keys.underscore("v2Url")
    assert_equal :sha256, Sink::Keys.underscore("sha256")
  end

  def test_underscores_non_string_keys
    assert_equal :created_at, Sink::Keys.underscore(:createdAt)
  end

  def test_camelizes_snake_case
    assert_equal "redirectWithQuery", Sink::Keys.camelize(:redirect_with_query)
    assert_equal "slug", Sink::Keys.camelize(:slug)
    assert_equal "expiresAt", Sink::Keys.camelize("expires_at")
  end

  def test_converts_hash_keys_without_touching_values
    nested = { "US" => "https://example.com/us" }

    assert_equal({ redirect_with_query: true, geo: nested }, Sink::Keys.underscore_keys("redirectWithQuery" => true, "geo" => nested))
    assert_equal({ "redirectWithQuery" => true, "geo" => nested }, Sink::Keys.camelize_keys(redirect_with_query: true, geo: nested))
  end

  def test_converts_empty_hashes
    assert_empty Sink::Keys.underscore_keys({})
    assert_empty Sink::Keys.camelize_keys({})
  end
end
