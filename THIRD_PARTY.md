# Third-Party Content

This document tracks vendored content in `superpowers-plus` and its source attribution.

## Vendored from upstream Superpowers

The entire workflow, hooks, and core skill library was forked from:

- **Project:** [obra/superpowers](https://github.com/obra/superpowers)
- **Author:** Jesse Vincent (jesse@fsck.com)
- **License:** MIT
- **Modifications:** atomic-issue decomposition added to brainstorming, domain routing added to subagent-driven-development, multi-harness support removed.

## Vendored from wshobson/dev-agents

(Phase 3 of the refactor. Not yet populated.)

The following specialist agents and skills will be vendored from [wshobson/dev-agents](https://github.com/wshobson/dev-agents). License and per-file attribution will be filled in when the vendoring lands.

### Agents (planned)

- `agents/python-pro.md` - source: `dev-agents/plugins/python-development/agents/python-pro.md`
- `agents/typescript-pro.md` - source: `dev-agents/plugins/javascript-typescript/agents/typescript-pro.md`
- `agents/javascript-pro.md` - source: `dev-agents/plugins/javascript-typescript/agents/javascript-pro.md`
- `agents/rust-pro.md` - source: `dev-agents/plugins/systems-programming/agents/rust-pro.md`
- `agents/golang-pro.md` - source: `dev-agents/plugins/systems-programming/agents/golang-pro.md`
- `agents/sql-pro.md` - source: `dev-agents/plugins/database-design/agents/sql-pro.md`

### Skills (planned)

- All 16 skills from `dev-agents/plugins/python-development/skills/`
- All 4 skills from `dev-agents/plugins/javascript-typescript/skills/`
- 3 skills from `dev-agents/plugins/systems-programming/skills/`: `go-concurrency-patterns`, `memory-safety-patterns`, `rust-async-patterns`
- `postgresql` from `dev-agents/plugins/database-design/skills/`

## Sync strategy

Vendored content is copied at a known revision and updated manually when wshobson ships changes worth pulling. See `scripts/sync-vendored.sh` (to be added in Phase 3) for the sync process.
