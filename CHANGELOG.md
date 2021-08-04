# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Support for configurable external gas price sources for relayers.
### Changed
- Logging to enable JSON format

## [1.7.0] - 2021-07-28
### Added
- Introduce `--override-origin` option to enable for adding params to origins (e.g. API Key).
- MATIC/USD
### Changed
- Make sure `install-omnia` works with the new config structures of spire and gofer.

## [1.6.1] - 2021-07-07
### Fixed
- Fixed default configurations 

## [1.6.0] - 2021-06-15
### Added
- Introduced second transport method to allow for more resilient price updates.

[Unreleased]: https://github.com/makerdao/oracles-v2/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/makerdao/oracles-v2/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/makerdao/oracles-v2/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/makerdao/oracles-v2/releases/tag/v1.6.0
