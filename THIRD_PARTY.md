# Third-Party Content

This document tracks vendored content in `superpowers-plus` and its source attribution.

## Forked from upstream superpowers

The workflow, hooks, and core skill library was forked from:

- **Project:** [obra/superpowers](https://github.com/obra/superpowers)
- **Author:** Jesse Vincent (jesse@fsck.com)
- **License:** MIT
- **Modifications:** specialist consultation added to brainstorming, domain routing added to subagent-driven-development, multi-harness support removed, plugin renamed.

The fork's full upstream license is preserved in `LICENSE`.

## Vendored from wshobson/agents

Specialist agents and skills vendored from:

- **Project:** [wshobson/agents](https://github.com/wshobson/agents)
- **Author:** Seth Hobson
- **License:** MIT (Copyright (c) 2024 Seth Hobson)
- **Modifications:** `model: opus` flipped to `model: inherit` on python-pro, typescript-pro, rust-pro, and golang-pro to align with upstream superpowers' code-reviewer pattern. Other content copied verbatim.
- **Sync:** `scripts/sync-vendored.sh` (default source `../agents`, configurable via `WSHOBSON_AGENTS` env var or `--source` flag).

The wshobson MIT license terms apply to all files listed below. Per the license, the copyright notice is reproduced here:

> Copyright (c) 2024 Seth Hobson
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Agents (6)

| Vendored at | Source path in wshobson/agents |
|---|---|
| `agents/python-pro.md` | `plugins/python-development/agents/python-pro.md` |
| `agents/typescript-pro.md` | `plugins/javascript-typescript/agents/typescript-pro.md` |
| `agents/javascript-pro.md` | `plugins/javascript-typescript/agents/javascript-pro.md` |
| `agents/rust-pro.md` | `plugins/systems-programming/agents/rust-pro.md` |
| `agents/golang-pro.md` | `plugins/systems-programming/agents/golang-pro.md` |
| `agents/sql-pro.md` | `plugins/database-design/agents/sql-pro.md` |

### Skills (24)

**Python (16)** from `plugins/python-development/skills/`:

| Vendored at | Source |
|---|---|
| `skills/async-python-patterns/` | `plugins/python-development/skills/async-python-patterns/` |
| `skills/python-anti-patterns/` | `plugins/python-development/skills/python-anti-patterns/` |
| `skills/python-background-jobs/` | `plugins/python-development/skills/python-background-jobs/` |
| `skills/python-code-style/` | `plugins/python-development/skills/python-code-style/` |
| `skills/python-configuration/` | `plugins/python-development/skills/python-configuration/` |
| `skills/python-design-patterns/` | `plugins/python-development/skills/python-design-patterns/` |
| `skills/python-error-handling/` | `plugins/python-development/skills/python-error-handling/` |
| `skills/python-observability/` | `plugins/python-development/skills/python-observability/` |
| `skills/python-packaging/` | `plugins/python-development/skills/python-packaging/` |
| `skills/python-performance-optimization/` | `plugins/python-development/skills/python-performance-optimization/` |
| `skills/python-project-structure/` | `plugins/python-development/skills/python-project-structure/` |
| `skills/python-resilience/` | `plugins/python-development/skills/python-resilience/` |
| `skills/python-resource-management/` | `plugins/python-development/skills/python-resource-management/` |
| `skills/python-testing-patterns/` | `plugins/python-development/skills/python-testing-patterns/` |
| `skills/python-type-safety/` | `plugins/python-development/skills/python-type-safety/` |
| `skills/uv-package-manager/` | `plugins/python-development/skills/uv-package-manager/` |

**JavaScript / TypeScript (4 shared)** from `plugins/javascript-typescript/skills/`:

| Vendored at | Source |
|---|---|
| `skills/javascript-testing-patterns/` | `plugins/javascript-typescript/skills/javascript-testing-patterns/` |
| `skills/modern-javascript-patterns/` | `plugins/javascript-typescript/skills/modern-javascript-patterns/` |
| `skills/nodejs-backend-patterns/` | `plugins/javascript-typescript/skills/nodejs-backend-patterns/` |
| `skills/typescript-advanced-types/` | `plugins/javascript-typescript/skills/typescript-advanced-types/` |

**Systems programming (3)** from `plugins/systems-programming/skills/`:

| Vendored at | Source |
|---|---|
| `skills/go-concurrency-patterns/` | `plugins/systems-programming/skills/go-concurrency-patterns/` |
| `skills/memory-safety-patterns/` | `plugins/systems-programming/skills/memory-safety-patterns/` |
| `skills/rust-async-patterns/` | `plugins/systems-programming/skills/rust-async-patterns/` |

**SQL (1)** from `plugins/database-design/skills/`:

| Vendored at | Source |
|---|---|
| `skills/postgresql/` | `plugins/database-design/skills/postgresql/` |

## Sync strategy

Vendored content is copied at a known revision and updated manually when wshobson ships changes worth pulling.

To sync:

```bash
./scripts/sync-vendored.sh --source /path/to/agents
git diff --stat
# review changes, commit if desired
```

The script reads its manifest internally and reports added/updated/unchanged/missing per item. Diff review is required before commit; never sync blind.
