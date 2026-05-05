# superpowers-plus

> A fork of [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent. **Claude Code only.**

Superpowers-plus extends the original superpowers workflow with two additions:

1. **Specialist consultation in design.** Brainstorming invokes language-specific design skills before proposing approaches, so specs reflect current idioms instead of training-data defaults.
2. **Domain-routed specialist agents.** During implementation, the controller infers the work's language and dispatches to a specialist agent (`python-pro`, `rust-pro`, etc.) instead of a generalist.

Twenty-four specialist skills and six specialist agents are bundled, covering Python, TypeScript, JavaScript, Rust, Go, and SQL.

## What's different from upstream

| Area | Upstream `superpowers` | This fork `superpowers-plus` |
|---|---|---|
| Harness support | Claude Code, Codex, Cursor, OpenCode, Gemini CLI, Copilot CLI | Claude Code only |
| Specialist consultation in brainstorming | None | Brainstormer invokes language-specific design skills before proposing approaches |
| Implementer subagent | Always `general-purpose` | Domain-routed: `python-pro`, `rust-pro`, `typescript-pro`, `javascript-pro`, `golang-pro`, `sql-pro`, with `general-purpose` fallback |
| Specialist skills | None bundled | 24 skills bundled across Python, JS/TS, Rust, Go, SQL |

The rest of the workflow - TDD, systematic debugging, git-worktrees, finishing-a-development-branch - is unchanged.

## Why fork

Stock superpowers' brainstorming relies on Claude's training-data of any given language. When working in Python, Rust, etc., specs and implementations don't reflect current idioms or library state. Specialist skills exist but stock brainstorming has no mechanism to consult them. This fork wires specialist consultation into the design phase and routes the implementer subagent to a domain-matched specialist agent.

## Installation

**Claude Code only.** This fork removes multi-harness support; vendored specialist agents are a Claude Code feature.

Register the marketplace and install:

```bash
/plugin marketplace add slgoodrich/superpowers-plus
/plugin install superpowers-plus@superpowers-plus-marketplace
```

If you have stock `superpowers` installed, you can keep both - they have different plugin names and don't collide. Disable one or the other via `/plugin` to compare.

## What's bundled

### Specialist agents (6)

| Domain | Agent |
|---|---|
| Python | `python-pro` |
| TypeScript | `typescript-pro` |
| JavaScript | `javascript-pro` |
| Rust | `rust-pro` |
| Go | `golang-pro` |
| SQL | `sql-pro` |

Plus the existing `code-reviewer` agent from superpowers.

### Specialist skills (24)

- **Python (16):** all skills from wshobson's `python-development` plugin
- **JS/TS (4):** shared skills covering testing, modern patterns, Node backends, advanced types
- **Systems (3):** rust-async-patterns, memory-safety-patterns (Rust), go-concurrency-patterns
- **SQL (1):** postgresql

## The Workflow

The core flow follows superpowers' design, with specialist consultation added in brainstorming and domain routing added in subagent-driven-development:

1. **brainstorming** - Refines the idea, consults specialist skills for the languages in scope, presents design
2. **writing-plans** - Produces an implementation plan
3. **subagent-driven-development** - Dispatches to a domain-matched specialist with two-stage review
4. **test-driven-development** - RED-GREEN-REFACTOR
5. **code-review** - Reviews against plan, reports by severity, integrates feedback
6. **finishing-a-development-branch** - PR, merge

## Philosophy

Same as upstream superpowers:

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

## Forking and customizing

If the bundled specialist set or routing doesn't match your stack, fork the repo and edit directly. See [COOKBOOK.md](COOKBOOK.md) for recipes covering: adding or removing specialist agents, swapping a vendored agent for your own, adding domain skills, and syncing updates from upstream wshobson.

Per-user shadowing is also supported without forking. Drop files in `~/.claude/agents/` or `~/.claude/skills/`; Claude Code prefers user-scoped files over plugin-scoped ones.

## Attribution and License

This fork is MIT-licensed, same as upstream.

- Core superpowers content: copyright Jesse Vincent and Prime Radiant. See [obra/superpowers](https://github.com/obra/superpowers) and the original [release announcement](https://blog.fsck.com/2025/10/09/superpowers/).
- Vendored specialist agents and skills: see `THIRD_PARTY.md` for source attribution and licensing.

This fork stands on the work of two open-source authors. If it has helped you, consider sponsoring both:

- [Jesse Vincent](https://github.com/sponsors/obra) - the superpowers workflow this fork is built on
- [Seth Hobson](https://github.com/sponsors/wshobson) - the specialist agents and skills bundled in

## Issues and Contributions

This fork is solo-maintained. Reviews may take time, and the opinionated direction (specialist consultation in design, domain-routed implementer) shapes what fits.

Before opening a PR:

- Search existing issues and PRs in this repo for duplicates
- Read `CLAUDE.md` for contributor guidelines
- For substantive workflow changes (skills that shape agent behavior), include eval evidence

For issues with the underlying superpowers design (skills, hooks, philosophy that this fork inherits unchanged), upstream is the better venue.
