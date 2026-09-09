# frozen_string_literal: true

require "test_helper"

class SinkLinkTest < Minitest::Test
  cover "Sink::Link*"

  def test_reads_unknown_fields_without_a_reader
    link = Sink::Link.from_response({ "slug" => "example", "futureField" => "value" })

    assert_equal "value", link[:future_field]
    assert_equal "value", link["future_field"]
    assert_nil link[:missing]
  end

  def test_serializes_to_snake_case_hash
    link = Sink::Link.from_response({ "link" => { "slug" => "a", "createdAt" => 1 }, "shortLink" => "https://s/a" })

    assert_equal({ slug: "a", created_at: 1, short_link: "https://s/a" }, link.to_h)
    assert_equal link.to_h, link.as_json
    assert_predicate link.attributes, :frozen?
    refute_predicate link.to_h, :frozen?
  end

  def test_defaults_collections_and_flags
    link = Sink::Link.from_response({ "slug" => "a" })

    assert_empty link.tags
    assert_empty link.geo
    assert_equal false, link.cloaking?
    assert_equal false, link.unsafe?
    assert_equal false, link.redirect_with_query?
    assert_equal false, link.expired?
    assert_nil link.created_at
    assert_nil link.updated_at
    assert_nil link.expires_at
  end

  def test_coerces_flags_to_booleans
    truthy = Sink::Link.new(cloaking: "1", unsafe: "1", redirect_with_query: "1")

    assert_equal true, truthy.cloaking?
    assert_equal true, truthy.unsafe?
    assert_equal true, truthy.redirect_with_query?

    falsy = Sink::Link.new(cloaking: false, unsafe: false, redirect_with_query: false)

    assert_equal false, falsy.cloaking?
    assert_equal false, falsy.unsafe?
    assert_equal false, falsy.redirect_with_query?
  end

  def test_reads_timestamps_as_utc_times
    link = Sink::Link.new(created_at: 1_700_000_000, updated_at: 1_700_000_500, expiration: 1_800_000_000)

    assert_equal Time.at(1_700_000_000).utc, link.created_at
    assert_equal Time.at(1_700_000_500).utc, link.updated_at
    assert_equal Time.at(1_800_000_000).utc, link.expires_at
    assert_equal 1_800_000_000, link.expiration
    assert_predicate link.created_at, :utc?
    assert_predicate link.updated_at, :utc?
    assert_predicate link.expires_at, :utc?
  end

  def test_reports_the_upsert_status
    assert_equal false, Sink::Link.new(status: "created").existing?
    assert_equal true, Sink::Link.new(status: "created").created?
    assert_equal false, Sink::Link.new(status: "existing").created?
    assert_equal true, Sink::Link.new(status: "existing").existing?
    assert_equal false, Sink::Link.new({}).created?
  end

  def test_reports_expired_links
    now = Time.now.to_i

    assert_equal true, Sink::Link.new(expiration: now - 60).expired?
    assert_equal false, Sink::Link.new(expiration: now + 60).expired?
  end

  def test_compares_by_attributes
    link = Sink::Link.new(slug: "a")

    assert_equal Sink::Link.new(slug: "a"), link
    assert link.eql?(Sink::Link.new(slug: "a"))
    refute_equal Sink::Link.new(slug: "b"), link
    refute_operator link, :==, "a"
    assert_instance_of Integer, link.hash
    assert_equal Sink::Link.new(slug: "a").hash, link.hash
    refute_equal Sink::Link.new(slug: "b").hash, link.hash
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

  def test_omits_short_link_and_blank_fields_without_a_base_url
    link = Sink::Link.from_response({ "slug" => "a" })

    assert_nil link.short_link
    assert_equal({ slug: "a" }, link.to_h)
  end

  def test_unwraps_the_link_key_only_when_it_is_a_hash
    assert_equal "a", Sink::Link.from_response({ "link" => { "slug" => "a" } }).slug
    assert_equal "a", Sink::Link.from_response({ "link" => "unexpected", "slug" => "a" }).slug
  end

  def test_from_response_ignores_non_hash_bodies
    assert_nil Sink::Link.from_response(nil)
    assert_nil Sink::Link.from_response("no")
  end
end

class SinkPageTest < Minitest::Test
  cover "Sink::Page*"

  def test_behaves_like_a_collection
    page = Sink::Page.new(records: %w[a b], cursor: "next", complete: false)

    assert_equal %w[a b], page.to_a
    assert_equal %w[A B], page.map(&:upcase)
    assert_equal 2, page.size
    assert_equal 2, page.length
    assert_equal "a", page[0]
    assert_equal %w[a b], page[0..1]
    refute page.empty?
    assert page.more?
  end

  def test_freezes_the_records
    assert_predicate Sink::Page.new(records: %w[a]).records, :frozen?
  end

  def test_needs_a_cursor_and_an_incomplete_list_to_have_more
    assert_equal false, Sink::Page.new(records: [], cursor: "next", complete: true).more?
    assert_equal false, Sink::Page.new(records: [], cursor: nil, complete: false).more?
  end

  def test_coerces_completeness_to_a_boolean
    assert_equal false, Sink::Page.new(records: [], complete: nil).complete?
    assert_equal true, Sink::Page.new(records: [], complete: "yes").complete?
  end

  def test_inspect_reports_state
    assert_equal "#<Sink::Page size=0 cursor=nil complete=true>", Sink::Page.new(records: []).inspect
    assert_equal(
      '#<Sink::Page size=1 cursor="next" complete=false>',
      Sink::Page.new(records: %w[a], cursor: "next", complete: false).inspect
    )
  end
end

class SinkTagTest < Minitest::Test
  cover "Sink::Tag*"

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
