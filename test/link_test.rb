# frozen_string_literal: true

require "test_helper"

class SinkLinkTest < Minitest::Test
  def test_reads_unknown_fields_without_a_reader
    link = Sink::Link.from_response({ "slug" => "example", "futureField" => "value" })

    assert_equal "value", link[:future_field]
    assert_nil link[:missing]
  end

  def test_serializes_to_snake_case_hash
    link = Sink::Link.from_response({ "link" => { "slug" => "a", "createdAt" => 1 }, "shortLink" => "https://s/a" })

    assert_equal({ slug: "a", created_at: 1, short_link: "https://s/a" }, link.to_h)
    assert_equal link.to_h, link.as_json
  end

  def test_defaults_collections_and_flags
    link = Sink::Link.from_response({ "slug" => "a" })

    assert_empty link.tags
    assert_empty link.geo
    refute link.cloaking?
    refute link.unsafe?
    refute link.redirect_with_query?
    refute link.expired?
    assert_nil link.created_at
    assert_nil link.expires_at
  end

  def test_reports_expired_links
    assert Sink::Link.new(expiration: Time.now.to_i - 60).expired?
    refute Sink::Link.new(expiration: Time.now.to_i + 60).expired?
  end

  def test_compares_by_attributes
    link = Sink::Link.new(slug: "a")

    assert_equal Sink::Link.new(slug: "a"), link
    refute_equal Sink::Link.new(slug: "b"), link
    refute_equal "a", link
    assert_equal Sink::Link.new(slug: "a").hash, link.hash
  end

  def test_inspect_shows_slug_and_url
    link = Sink::Link.new(slug: "a", url: "https://example.com")

    assert_equal '#<Sink::Link slug="a" url="https://example.com">', link.inspect
  end

  def test_prefers_the_short_link_from_the_response
    body = { "link" => { "slug" => "a" }, "shortLink" => "https://custom.example/a" }

    assert_equal "https://custom.example/a", Sink::Link.from_response(body, base_url: "https://sink.example").short_link
  end

  def test_omits_short_link_without_a_slug
    assert_nil Sink::Link.from_response({ "id" => "1" }, base_url: "https://sink.example").short_link
  end

  def test_from_response_ignores_non_hash_bodies
    assert_nil Sink::Link.from_response(nil)
    assert_nil Sink::Link.from_response("no")
  end
end

class SinkPageTest < Minitest::Test
  def test_behaves_like_a_collection
    page = Sink::Page.new(records: %w[a b], cursor: "next", complete: false)

    assert_equal %w[a b], page.to_a
    assert_equal %w[A B], page.map(&:upcase)
    assert_equal 2, page.size
    assert_equal 2, page.length
    assert_equal "a", page[0]
    refute page.empty?
    assert page.more?
  end

  def test_inspect_reports_state
    page = Sink::Page.new(records: [])

    assert_equal "#<Sink::Page size=0 cursor=nil complete=true>", page.inspect
  end
end

class SinkTagTest < Minitest::Test
  def test_builds_from_hash_and_string
    tag = Sink::Tag.from_response({ "name" => "articles", "count" => 2 })

    assert_equal "articles", tag.name
    assert_equal 2, tag.count
    assert_equal "articles", tag.to_s

    legacy = Sink::Tag.from_response("articles")

    assert_equal "articles", legacy.name
    assert_nil legacy.count
  end
end

class SinkKeysTest < Minitest::Test
  def test_converts_between_naming_conventions
    assert_equal :redirect_with_query, Sink::Keys.underscore("redirectWithQuery")
    assert_equal :user_id, Sink::Keys.underscore("userID")
    assert_equal :list_complete, Sink::Keys.underscore("list_complete")
    assert_equal "redirectWithQuery", Sink::Keys.camelize(:redirect_with_query)
    assert_equal "slug", Sink::Keys.camelize(:slug)
  end
end
