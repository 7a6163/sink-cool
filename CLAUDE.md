# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle install
bundle exec rake test                                  # full suite (default rake task)
bundle exec ruby -Ilib -Itest test/client_test.rb      # one file
bundle exec ruby -Ilib -Itest test/client_test.rb -n test_link_endpoints   # one test
bundle exec rake mutant                                # mutation coverage, ~90s
bundle exec mutant run 'Sink::Client#request'          # one mutation subject
gem build sink-cool.gemspec
```

Coverage lands in `coverage/` (SimpleCov, HTML + JSON); CI uploads `coverage/coverage.json` to Codecov.
`RUBYOPT=-W0` silences the parser gem's Ruby 4.0 warnings, which otherwise bury mutant's output.

## Project shape

The gem is `sink-cool`, the module is `Sink` — a Ruby client for the [Sink](https://docs.sink.cool/api/)
URL shortener API. Ruby >= 3.3, **zero runtime dependencies** (stdlib `net/http`, `json`, `uri`,
`openssl` only). Don't add one; the whole HTTP layer is ~60 lines in `lib/sink/client.rb`.

`lib/sink-cool.rb` exists only so `require "sink-cool"` (the gem name) works; it requires `lib/sink.rb`,
which is the real entry point.

## Architecture

**Global config + memoized client** (`lib/sink.rb`). `Sink.configure` copies the current
`Configuration` struct, yields the copy, then swaps it in and nils the memoized `@client` under
`CLIENT_MUTEX`. `Sink.client` builds from that config. A `Sink::Client.new(base_url:, token:)` is
independent of the global state — most tests use that.

**One request funnel** (`lib/sink/client.rb`). Every public method routes through the private
`request` → `dispatch` → `perform_request` → `parse_response` chain:

- `dispatch` converts `TIMEOUT_ERRORS`/`CONNECTION_ERRORS` into `Sink::TimeoutError`/`ConnectionError`.
- `perform_request` is the single `Net::HTTP.start` call and the **only seam the tests stub** — see
  `stub_transport` in `test/client_test.rb`, which defines `perform_request` on the client's singleton
  class and removes it in `ensure`. No WebMock. Any new HTTP path must go through `request` or it is
  untestable.
- `parse_response` raises `Sink::Error.for(...)`, which maps status codes to subclasses via
  `STATUS_ERRORS` in `lib/sink/error.rb` (5xx falls back to `ServerError`). Add a new status by adding
  a class and a hash entry there, not a rescue at a call site.

**Key translation** (`lib/sink/keys.rb`). Public API is snake_case; the wire is camelCase.
Outgoing payloads pass `Keys.camelize_keys`, responses pass `Keys.underscore_keys`. Only top-level
keys are converted — nested hashes like `geo` keep their country-code keys.

**Attribute whitelist.** `Client::LINK_ATTRIBUTES` gates every write; unknown keys raise
`ArgumentError` rather than being silently dropped by the API. Adding a link field means adding it to
`LINK_ATTRIBUTES` *and* `Link::ATTRIBUTES`. `expires_at` is sugar: it is converted to a unix
`expiration` in `link_payload`.

**Value objects.** `Link` (frozen attribute hash, `[]` for fields with no reader, predicate readers
like `expired?`/`created?`), `Page` (`Enumerable`, `cursor`/`complete?`/`more?`), `Tag` (`Data.define`).
Collections are normalized by the private `page(body, key)` helper, which tolerates both an array
response and a `{key, cursor, list_complete}` hash. `each_link` walks cursors on top of `links`.

**`short_link` derivation.** The API returns `shortLink` only for write endpoints (it builds it from
the request host). `Link.from_response` therefore synthesizes it from the client's `base_url` + slug
for `link`, `links`, and `search_links`. This is correct only when `base_url` is the Worker domain.

## Mutation testing

Line coverage is 100%, so mutant (config in `.mutant.yml`, `usage: opensource`) is the real signal.
Three things make it work, and breaking any of them silently reports everything as alive:

- **Every test class declares `cover "Sink::Link*"`** (from `mutant/minitest/coverage`, required in
  `test_helper.rb`). Without it mutant selects zero tests and every mutation "survives". A new test
  file needs both a `cover` line and an entry in `.mutant.yml`'s `requires`.
- **`test_helper.rb` skips SimpleCov when `Mutant` is defined** — mutant forks per mutation and the
  children would trample `coverage/`.
- **`Sink::Keys` uses `extend self`, not `module_function`.** `module_function` *copies* each method
  to the singleton, so mutating the instance method leaves `Sink::Keys.underscore` untouched and every
  mutation survives. Same trap applies to any future module of helpers.

~52 of 1906 mutations stay alive and that is the expected steady state, not a gap to close: mostly
equivalent pairs (`@attributes[:tags]` vs `self[:tags]`, `is_a?` vs `instance_of?`, `to_i` vs
`Integer()`) plus `perform_request`'s HTTPS and open-timeout arguments, which need a real TLS
handshake or an unroutable host to distinguish. Mutant exits nonzero whenever anything is alive, so
it is a local tool, not a CI gate.

`test/transport_test.rb` is the only test that lets `perform_request` run for real; it talks to a
throwaway `TCPServer`. Everything else stubs `perform_request` on the client's singleton class.

## Releasing

Bump `Sink::VERSION` in `lib/sink/version.rb` and add the matching `CHANGELOG.md` section, then push a
`v<version>` tag. `.github/workflows/release.yml` hard-fails if the tag and `Sink::VERSION` disagree,
extracts release notes by matching the `## <version>` heading in `CHANGELOG.md`, and publishes to
RubyGems (trusted publishing), GitHub Packages, and GitHub Releases — each step skips if that version
is already published, so re-tagging is safe.
