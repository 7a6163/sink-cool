# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

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
