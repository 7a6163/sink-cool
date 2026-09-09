# sink-cool

[![CI](https://github.com/7a6163/sink-cool/actions/workflows/ci.yml/badge.svg)](https://github.com/7a6163/sink-cool/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/sink-cool.svg)](https://rubygems.org/gems/sink-cool)
[![codecov](https://codecov.io/gh/7a6163/sink-cool/branch/main/graph/badge.svg)](https://codecov.io/gh/7a6163/sink-cool)

Ruby client for the [Sink](https://sink.cool/) URL shortener API.

Requires Ruby 3.3 or newer.

## Installation

Add the gem to your bundle:

```bash
bundle add sink-cool
```

Or install it directly:

```bash
gem install sink-cool
```

## Configuration

Create an initializer such as `config/initializers/sink.rb`:

```ruby
require "sink-cool"

Sink.configure do |config|
  config.base_url = ENV.fetch("SINK_BASE_URL")
  config.token = ENV.fetch("SINK_TOKEN")
end
```

Use HTTPS in production so the bearer token is encrypted in transit.

Optional HTTP timeouts:

```ruby
Sink.configure do |config|
  config.base_url = ENV.fetch("SINK_BASE_URL")
  config.token = ENV.fetch("SINK_TOKEN")
  config.open_timeout = 5
  config.read_timeout = 30
end
```

You can also create an independent client:

```ruby
client = Sink::Client.new(
  base_url: "https://sink.example.com",
  token: "site-token"
)
```

## Usage

```ruby
client = Sink.client

client.verify
# => { name: "Sink", auth_method: "site-token", user_email: "admin@example.com", ... }

client.create_link(
  url: "https://example.com/articles/1",
  slug: "article-1",
  tags: ["articles"],
  redirect_with_query: true,
  expires_at: 1.week.from_now
)

client.edit_link(url: "https://example.com/articles/2", slug: "article-1")
client.upsert_link(url: "https://example.com", slug: "example")
client.link("example")
client.links(limit: 20, sort: "newest", status: "active")
client.search_links(query: "example", tag: "articles")
client.tags
client.check_links(limit: 6, timeout: 6)
client.delete_link("example")
```

Attributes are snake_case and converted to the camelCase names the API expects,
so `redirect_with_query` is sent as `redirectWithQuery`. Unknown attributes
raise `ArgumentError` instead of being silently dropped by the server.
`expires_at` accepts a `Time`, a `Date`, or a unix timestamp.

### Links

`create_link`, `edit_link`, `upsert_link`, and `link` all return a `Sink::Link`:

```ruby
link = client.create_link(url: "https://example.com", slug: "example")

link.slug                  # => "example"
link.short_link            # => "https://sink.example.com/example"
link.created_at            # => 2026-07-24 12:00:00 UTC
link.expires_at            # => Time or nil
link.expired?              # => false
link.cloaking?             # => false
link.redirect_with_query?  # => true
link.tags                  # => ["articles"]
link.geo                   # => { "US" => "https://example.com/us" }
link.to_h                  # => { slug: "example", url: "https://example.com", ... }
link[:any_future_field]    # raw access to fields without a reader
```

The API only returns `shortLink` for the write endpoints, where it builds the
value from the protocol and host of the request. `short_link` is therefore
derived from `base_url` and the slug for `link`, `links`, and `search_links`,
which matches the API as long as `base_url` is the Worker domain that serves the
short links.

`upsert_link` never overwrites an existing slug, so check which happened:

```ruby
link = client.upsert_link(url: "https://example.com", slug: "example")

link.created?  # => true when the link was stored
link.existing? # => true when the slug already pointed somewhere else
```

`delete_link` returns `true`.

### Collections

`links`, `search_links`, and `check_links` return a `Sink::Page`, which is
`Enumerable`:

```ruby
page = client.links(limit: 20)

page.map(&:slug)
page.cursor     # => "..." pagination cursor
page.complete?  # => false when more pages are available
page.more?      # => true when a following page can be fetched
```

Use `each_link` to walk every page without handling cursors:

```ruby
client.each_link(tag: "articles") { |link| puts link.short_link }
client.each_link.lazy.select(&:expired?).first(10)
```

`tags` returns `Sink::Tag` records with `name` and `count`.

## Errors

Non-successful responses raise a subclass of `Sink::Error`, so a Rails
controller can rescue the cases it cares about:

```ruby
class LinksController < ApplicationController
  rescue_from Sink::NotFound, with: :not_found

  def create
    link = Sink.client.create_link(url: params[:url], slug: params[:slug])
    render json: link.to_h, status: :created
  rescue Sink::Conflict
    render json: { error: "slug already taken" }, status: :conflict
  end
end
```

| Class | Raised for |
| --- | --- |
| `Sink::ValidationError` | 400, 422 (`error.data` holds the API details) |
| `Sink::Unauthorized` | 401, usually a wrong site token |
| `Sink::Forbidden` | 403, including preview mode |
| `Sink::NotFound` | 404 |
| `Sink::Conflict` | 409, the slug already exists |
| `Sink::StorageNotReady` | 423, open Dashboard → Links once after deploying |
| `Sink::RateLimited` | 429 |
| `Sink::ServerError` | 5xx |
| `Sink::TimeoutError` | open or read timeout |
| `Sink::ConnectionError` | DNS, TLS, and socket failures |

Every error exposes `status`, `message`, `body`, and `data`:

```ruby
begin
  Sink.client.link("missing")
rescue Sink::Error => error
  error.status  # => 404
  error.message # => "Not Found"
  error.body    # => parsed response body
end
```

## Development

```bash
bundle install
bundle exec rake test
gem build sink-cool.gemspec
```

Line coverage is not enough for a client this small, so the suite is also
checked with [mutant](https://github.com/mbj/mutant):

```bash
bundle exec rake mutant                    # whole library, ~90s
bundle exec mutant run 'Sink::Client*'     # one subject
```

Each test class declares what it covers with `cover "Sink::Link*"`, which is how
mutant maps mutations to tests. Roughly fifty mutations stay alive on purpose:
they are equivalent (`@attributes[:tags]` versus `self[:tags]`) or need a real
TLS handshake to tell apart.

See the [Sink API documentation](https://docs.sink.cool/api/) for endpoint and
payload details.

## Releasing

Configure a trusted publisher for this repository and `release.yml` on
RubyGems.org. Update `Sink::VERSION` and the matching `CHANGELOG.md` section,
then push a matching version tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

The release workflow tests Ruby 3.3, 3.4, and 4.0 before publishing to
RubyGems.org, GitHub Packages, and GitHub Releases.

## License

This gem is available under the [MIT License](LICENSE.txt).
