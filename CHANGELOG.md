# Changelog

All notable changes to superpowers-plus are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

For upstream superpowers' release history, see [obra/superpowers](https://github.com/obra/superpowers/blob/main/RELEASE-NOTES.md).

## [Unreleased]

### Added

- Six language-specialist agents bundled from [wshobson/agents](https://github.com/wshobson/agents): `python-pro`, `typescript-pro`, `javascript-pro`, `rust-pro`, `golang-pro`, `sql-pro`.
- Twenty-four specialist skills covering Python (16), JavaScript/TypeScript (4), systems programming (3), and SQL (1). See `THIRD_PARTY.md` for the full list.
- `scripts/sync-vendored.sh` for reproducible re-syncs of vendored content from a local checkout of wshobson/agents.
- `THIRD_PARTY.md` documenting source attribution and licensing for vendored content.

### Changed

- Reset version to `0.1.0`. The fork is untested as a separate product; the previous `5.0.7` was inherited from upstream and implied parity that does not exist.
- Renamed the in-repo marketplace from `superpowers-plus-dev` to `superpowers-plus-marketplace`.
- Lowercased the project name (`superpowers`, `superpowers-plus`) in prose throughout the repo. Identifier-style casing matches package metadata.
- Author email in plugin manifests now uses the GitHub noreply address.

### Removed

- Multi-harness support. The fork is Claude Code only. Removed plugin manifests, install docs, harness-specific hooks, tool-mapping references, and integration tests for Codex, Cursor, OpenCode, Gemini CLI, and Copilot CLI.
