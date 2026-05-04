# Changelog

All notable changes to atomic-superpowers are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

For upstream superpowers' release history, see [obra/superpowers](https://github.com/obra/superpowers/blob/main/RELEASE-NOTES.md).

## [Unreleased]

### Added

- `atomic-superpowers:atomic-issues` skill. Reference for decomposing features into atomic, independently-shippable issues with the criteria (single coherent concern, single language/domain, shippable alone, single push or commit) and the "and" test.
- Decomposition step in `atomic-superpowers:brainstorming`. After the user approves the spec, the brainstormer decomposes the work into atomic issues and appends the issue list to the spec doc.
- Specialist consultation step in `atomic-superpowers:brainstorming`. Before proposing approaches, the brainstormer invokes the specialist skill(s) matching each language or domain in scope.
- Specialist Routing in `atomic-superpowers:subagent-driven-development`. The implementer subagent is now domain-routed (`python` → `python-pro`, `rust` → `rust-pro`, etc.) with `general-purpose` as the fallback.
- Six language-specialist agents bundled from [wshobson/agents](https://github.com/wshobson/agents): `python-pro`, `typescript-pro`, `javascript-pro`, `rust-pro`, `golang-pro`, `sql-pro`.
- Twenty-four specialist skills covering Python (16), JavaScript/TypeScript (4), systems programming (3), and SQL (1). See `THIRD_PARTY.md` for the full list.
- `scripts/sync-vendored.sh` for reproducible re-syncs of vendored content from a local checkout of wshobson/agents. Default source path is `../agents`; override with `WSHOBSON_AGENTS` env var or `--source` flag.
- `COOKBOOK.md` documenting recipes for forkers: adding, swapping, removing specialist agents and skills; syncing updates from upstream wshobson; per-user shadowing as an alternative to forking.
- `THIRD_PARTY.md` documenting source attribution and licensing for vendored content.

### Changed

- `atomic-superpowers:writing-plans` consumes one atomic issue at a time and produces one plan per issue.
- Vendored `python-pro`, `typescript-pro`, `rust-pro`, and `golang-pro` use `model: inherit` instead of upstream wshobson's `model: opus`. The dispatcher's Model Selection guidance applies uniformly across all specialists; the sync script re-applies the override on each run.

### Removed

- Multi-harness support. The fork is Claude Code only. Plugin manifests, install docs, harness-specific hooks, tool-mapping references, and integration tests for Codex, Cursor, OpenCode, Gemini CLI, and Copilot CLI are not present.
