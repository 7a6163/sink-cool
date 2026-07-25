# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

## 0.2.0 - 2026-07-24

### Added

- `Sink::Link` value objects with snake_case readers, `Time` timestamps, predicate methods, `to_h`, and `[]` access to fields without a reader.
- `Sink::Page` collections including `Enumerable`, exposing `cursor`, `complete?`, and `more?`.
- `Sink::Tag` records with `name` and `count`.
- `Client#each_link` to iterate every page without handling cursors manually.
- Error subclasses for each API failure mode: `Sink::ValidationError`, `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`, `StorageNotReady`, `RateLimited`, `ServerError`, `ConnectionError`, and `TimeoutError`.
- `Sink::Error#data` for the validation details returned by the API.

### Changed

- **Breaking:** link endpoints return `Sink::Link` and `Sink::Page` objects instead of raw hashes and arrays. Call `to_h` for the previous key names in snake_case.
- **Breaking:** link attributes are passed as snake_case keyword arguments and camelized for the API, so `redirectWithQuery` becomes `redirect_with_query`. Unknown attributes now raise `ArgumentError`.
- **Breaking:** `create_link`, `edit_link`, and `upsert_link` take keyword arguments, with `url` required by all three and `slug` also required by `edit_link`.
- **Breaking:** `delete_link` returns `true` instead of `nil`.
- **Breaking:** `verify` returns a hash with snake_case symbol keys.
- `expires_at` accepts a `Time`, a `Date`, or a unix timestamp and is sent as `expiration`.
- Timeouts, TLS, and socket failures raise `Sink::Error` subclasses instead of leaking `Net::HTTP` exceptions.

### Fixed

- Skip blank `message` values when building error messages, so the Sink API `statusMessage` is no longer replaced by an empty string.
- Read `statusText` as an error message source, matching newer Sink releases.
- Validate the token before the base URL so an empty token reports the right argument.

## 0.1.2 - 2026-07-23

### Fixed

- Grant the release workflow write access so gems reach GitHub Packages.
- Make the release workflow idempotent, skipping RubyGems and GitHub Packages pushes for versions that already exist.

## 0.1.1 - 2026-07-23

### Fixed

- Avoid false release failures while RubyGems propagates its full index.

## 0.1.0 - 2026-07-23

### Added

- Global configuration for the Sink base URL, site token, and HTTP timeouts.
- Client methods for authentication, link management, search, tags, and link checks.
- Structured `Sink::Error` exceptions for unsuccessful API responses.
- GitHub Actions workflows for CI and trusted publishing to RubyGems.org.
- MIT License.
- RubyGems project metadata.

### Changed

- Require Ruby 3.3 or newer, matching the tested versions.
- Publish version tags to RubyGems.org, GitHub Packages, and GitHub Releases after running the full Ruby version matrix.
- Make global client initialization thread-safe.
- Isolate HTTP transport in tests without patching `Net::HTTP` globally.
