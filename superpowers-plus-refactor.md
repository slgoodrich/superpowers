# Superpowers-Plus Refactor

Planning document for forking `obra/superpowers` into `superpowers-plus`. Tracks the decisions made, the changes needed, and what's deliberately out of scope.

## Why fork

Stock superpowers' brainstorming is a generalist relying on Claude's training data. When working in Python, Rust, etc., the specs and implementations don't reflect current idioms or library state. Specialist skills exist (wshobson/dev-agents) but stock brainstorming has no mechanism to consult them. Worse, brainstorming explicitly forbids invoking other skills during design, which prevents specialist consultation even when relevant skills are installed.

Stock superpowers also produces large monolithic plans (often 2000+ lines) for whole features. Atomic issues with per-issue plans are easier to test, review, and ship.

## Goal

Bring specialist expertise to brainstorming and implementation, decompose work into atomic units, while preserving the rest of stock superpowers' workflow and discipline.

## Three additive changes

1. **Atomic issues in brainstorming**: spec output includes a decomposed issue list. One concern, one domain, independently shippable per `atomic-issues.md`.
2. **Domain-inferred routing in subagent-driven-development**: when dispatching the implementer subagent, the controller infers the issue's domain from the plan content and routes to the matching specialist agent (python-pro, rust-pro, etc.) with general-purpose as fallback.
3. **Vendored specialist agents and skills**: a curated subset of wshobson's dev-agents content is copied into superpowers-plus so users get specialists out of the box.

## Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Distribution | Vendor wshobson's content | Routing reliability, no install friction, review gate on upstream changes |
| Specialist scope | Core languages: python, rust, typescript, golang, sql | Wide coverage, small surface |
| Routing mechanism | Inferred at dispatch time from plan content | YAGNI - explicit declaration only if inference proves unreliable |
| Issue execution | Sequential, one PR per issue, wait for merge | Matches existing superpowers flow; merge gate handles deps |
| Multi-reviewer (security/perf) | Out of scope | Stays in user's personal `/review` command; too project-specific to generalize |
| Parallel issue execution | Out of scope | Sequential merge is the design |
| Domain frontmatter | Skip | Inferred routing is enough until proven otherwise |
| Path-trigger config | Skip | Multi-reviewer is out of scope |
| README | Keep Jesse's + add fork attribution | Honest fork etiquette, link upstream |
| Harness support | Claude Code only | Vendored agents are Claude Code only; multi-harness scaffolding is dead weight |

## Phases

### Phase 1a: Strip non-Claude-Code support

Vendored specialist agents are a Claude Code feature. Multi-harness support is dead weight.

**Delete top-level directories:**
- `.codex/`
- `.codex-plugin/`
- `.cursor-plugin/`
- `.opencode/`

**Delete top-level files:**
- `gemini-extension.json`
- `GEMINI.md`
- `AGENTS.md` (Codex shim - just a single-line redirect to CLAUDE.md)
- `docs/README.codex.md`
- `docs/README.opencode.md`
- `scripts/sync-to-codex-plugin.sh`

**Keep:**
- `tests/brainstorm-server/` - tests the visual brainstorming companion server (part of brainstorming skill, harness-agnostic)

**Hooks:**
- Delete `hooks/hooks-cursor.json`
- Simplify `hooks/session-start` to Claude Code only path (strip Cursor/Copilot branches)

**Skills:**
- Delete `skills/using-superpowers/references/codex-tools.md`
- Delete `skills/using-superpowers/references/copilot-tools.md`
- Delete `skills/using-superpowers/references/gemini-tools.md`
- Edit `skills/using-superpowers/SKILL.md` - strip non-Claude-Code platform sections

**Tests:**
- Delete `tests/opencode/`
- Delete `tests/codex-plugin-sync/`

**Other:**
- `package.json`: drop `"main"` field (existed for OpenCode); reduce to name + version
- `scripts/bump-version.sh` and `.version-bump.json`: simplify to bump only Claude Code manifest
- `CLAUDE.md`: remove "must work across all coding agents we support" contributor guidance

### Phase 1b: Identity and rename

Mechanical changes to make the fork installable side-by-side with stock superpowers.

- `.claude-plugin/plugin.json` - name to `superpowers-plus`
- `.claude-plugin/marketplace.json` - plugin entry name + marketplace name
- `package.json` - name field
- Active `superpowers:` namespace references → `superpowers-plus:` in:
  - `skills/*/SKILL.md`
  - `skills/*-prompt.md` (subagent-driven-development prompts)
  - `hooks/session-start`
  - `commands/*.md`
  - `CLAUDE.md`
  - `.github/PULL_REQUEST_TEMPLATE.md`
- Keep `superpowers:` references in historical/documentary files:
  - `RELEASE-NOTES.md`
  - `docs/plans/*`
  - `docs/superpowers/*`
- Update author/repo URLs in manifests to fork's URLs
- README: prepend a "This is a fork of obra/superpowers" attribution block, document what's different, link upstream, remove install sections for non-Claude-Code harnesses
- Add `THIRD_PARTY.md` for vendored content attribution (filled in Phase 3)

### Phase 2: Workflow edits

Three skill files change.

#### `skills/brainstorming/SKILL.md`

- Add a step after design approval: "Decompose into atomic issues per `superpowers-plus:atomic-issues`"
- Output of brainstorming is now: spec document + decomposed issue list
- Terminal state changes from "invoke writing-plans" to "for the first issue, invoke writing-plans"
- Soften the "do NOT invoke any other skill" line to permit consultative skills (specialist domain knowledge) while still forbidding implementation skills (frontend-design, mcp-builder)

#### `skills/writing-plans/SKILL.md`

- Input is now one atomic issue at a time (not a whole feature spec)
- Plans should be length-bounded (target: under 200 lines, hard cap to be defined)
- If a plan exceeds the cap, the issue probably isn't atomic - escalate back to brainstorming for re-decomposition

#### `skills/subagent-driven-development/SKILL.md`

- Add routing table: domain → subagent_type
  - python → python-pro
  - rust → rust-pro
  - typescript → typescript-pro
  - golang → golang-pro
  - sql → sql-pro
  - (no match) → general-purpose
- Parameterize `implementer-prompt.md` with `[SUBAGENT_TYPE]` placeholder
- At dispatch time, controller infers domain from plan content, looks up subagent_type, substitutes into prompt
- If inference is ambiguous or no specialist matches, fall back to general-purpose and log the choice

#### New: `skills/atomic-issues/SKILL.md`

- Adapted from `atomic-issues.md` reference doc
- Defines the atomicity rules (one concern, one domain, independently shippable)
- Used by brainstorming during decomposition

### Phase 3: Vendor specialist content

**Selection rule:** ship the agent if it has at least one associated skill in dev-agents. Languages with zero skills (Java, C#, Scala, Elixir, Haskell, Bash, C, C++) are dropped from v1 - implementation persona without design consultation is asymmetric value.

#### Agents to vendor (6)

| Domain | Agent | Source |
|---|---|---|
| python | python-pro.md | python-development/agents/ |
| typescript | typescript-pro.md | javascript-typescript/agents/ |
| javascript | javascript-pro.md | javascript-typescript/agents/ |
| rust | rust-pro.md | systems-programming/agents/ |
| go | golang-pro.md | systems-programming/agents/ |
| sql | sql-pro.md | database-design/agents/ |

Copied into `agents/` of superpowers-plus. The existing `agents/code-reviewer.md` is unchanged.

#### Skills to vendor (24, no duplicates)

**Python (16)**: all skills from `python-development/skills/`

async-python-patterns, python-anti-patterns, python-background-jobs, python-code-style, python-configuration, python-design-patterns, python-error-handling, python-observability, python-packaging, python-performance-optimization, python-project-structure, python-resilience, python-resource-management, python-testing-patterns, python-type-safety, uv-package-manager

**JS/TS (4 shared)** from `javascript-typescript/skills/`:

javascript-testing-patterns, modern-javascript-patterns, nodejs-backend-patterns, typescript-advanced-types

**Systems (3)** from `systems-programming/skills/`:

go-concurrency-patterns, memory-safety-patterns, rust-async-patterns

**SQL (1)** from `database-design/skills/postgresql/`

Copied into `skills/` of superpowers-plus.

#### Routing table

Each domain maps to its agent + the skills relevant to that domain. Skills are shipped once but referenced by multiple domains where appropriate.

```
python     → python-pro     + [all 16 python-* skills + uv-package-manager]
typescript → typescript-pro + [typescript-advanced-types, modern-javascript-patterns, nodejs-backend-patterns, javascript-testing-patterns]
javascript → javascript-pro + [modern-javascript-patterns, nodejs-backend-patterns, javascript-testing-patterns]
rust       → rust-pro       + [rust-async-patterns, memory-safety-patterns]
go         → golang-pro     + [go-concurrency-patterns]
sql        → sql-pro        + [postgresql]
(no match) → general-purpose, no skills
```

Note: `memory-safety-patterns` is routed to Rust only, not Go (Go has GC).

#### Sync strategy

- One-shot copy script: `scripts/sync-vendored.sh`
- Reads a manifest listing source paths in `dev-agents/`
- Copies into superpowers-plus directories
- Run manually when wshobson updates land that you want
- Diff review before commit (no blind sync)

#### Attribution

- `THIRD_PARTY.md` at root listing each vendored file, source URL, and license
- Per-file header comment if license requires it

## Out of scope

Documented for clarity:

- Multi-reviewer integration with security/performance reviewers (stays in personal `/review`)
- Path-trigger configuration system
- Worktree workflow changes
- Parallel atomic issue execution
- Domain frontmatter on issues
- Project-level domain vocabulary file
- Stack auto-detection in brainstorming (the brainstormer asks; doesn't probe)

## Open questions

- Whether `using-git-worktrees` needs a small note about per-issue worktrees, or stays untouched

## Resolved

- Plan length cap: **none**. Atomicity is expected to keep plans short. If plans bloat anyway, revisit.
- Agent list: **6 language agents** (python, ts, js, rust, go, sql) per the rule "skip if no associated skills"
- Skill list: **24 skills** across 4 source plugins (locked in Phase 3)
- `tests/brainstorm-server/` and `AGENTS.md`: kept and deleted respectively (Phase 1a)

## Validation plan

After Phase 1 + 2 (before Phase 3):

1. Install superpowers-plus alongside stock superpowers
2. Disable stock; enable plus
3. Pick a Python feature idea
4. Run brainstorm in plus, observe whether decomposition happens and specialists are consulted (using already-installed dev-agents skills)
5. Re-enable stock, disable plus, run same brainstorm in stock
6. Compare specs on:
   - Mention of current library versions/idioms
   - Decomposition into atomic units
   - Length and clarity

If plus produces measurably better specs, proceed to Phase 3. If not, the workflow edits aren't pulling their weight - revise before vendoring.

## Status

- Decisions: locked
- Phase 1: not started
- Phase 2: not started
- Phase 3: not started
