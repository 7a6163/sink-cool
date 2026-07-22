# sink-cool

Ruby client for the [Sink](https://sink.cool/) URL shortener API.

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

client.create_link(
  url: "https://example.com/articles/1",
  slug: "article-1",
  tags: ["articles"]
)

client.edit_link(
  url: "https://example.com/articles/2",
  slug: "article-1",
  tags: ["articles"]
)

client.upsert_link(url: "https://example.com", slug: "example")
client.link("example")
client.links(limit: 20, sort: "newest", status: "active")
client.search_links(query: "example", tag: "articles")
client.tags
client.check_links(limit: 6, timeout: 6)
client.delete_link("example")
```

API responses are returned as Ruby hashes or arrays. Requests returning HTTP
204 return `nil`.

## Errors

Non-successful responses raise `Sink::Error`:

```ruby
begin
  Sink.client.link("missing")
rescue Sink::Error => error
  error.status
  error.message
  error.body
end
```

## Development

```bash
bundle install
bundle exec rake test
gem build sink-cool.gemspec
```

See the [Sink API documentation](https://docs.sink.cool/api/) for endpoint and
payload details.
