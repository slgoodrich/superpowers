# Cookbook

How to modify your fork of superpowers-plus to fit your stack.

You've forked the repo. The agents, skills, and routing tables are yours to edit. This doc shows what to change for common modifications.

## What gets routed where

Two places reference agents and skills by name. When you add, swap, or remove, those are the files to update.

| Routing table | File | What it does |
|---|---|---|
| Specialist consultation in design | `skills/brainstorming/SKILL.md`, "Consulting specialist skills" section | Tells the brainstormer which skills to invoke for each language during design |
| Domain → subagent_type | `skills/subagent-driven-development/SKILL.md`, "Specialist Routing" section | Tells the controller which specialist agent to dispatch for each domain |

If your change adds or removes a domain (a language or platform), update both. If it's a new skill within an existing domain, only the brainstorming routing needs an update.

## Add a specialist agent for a new language

Example: bundling `php-pro` so issues tagged `php` route to a specialist.

1. Add `agents/php-pro.md` with frontmatter:

   ```yaml
   ---
   name: php-pro
   description: Use PROACTIVELY for PHP development, Laravel/Symfony work, modernization from older PHP versions.
   model: inherit
   ---

   You are a PHP expert specializing in...
   ```

2. Add at least one supporting skill (see next recipe). Without skill content, the agent has no design-time context to consult.

3. Update both routing tables:
   - `skills/brainstorming/SKILL.md` "Consulting specialist skills" - add `php → php-design-patterns, ...`
   - `skills/subagent-driven-development/SKILL.md` "Specialist Routing" table - add `| php | php-pro |`

The agent's `description` matters for routing. The controller picks specialists by matching the issue's domain to the agent's name and description; vague descriptions cause misroutes.

## Add a skill within an existing domain

Example: `python-async-testing` for testing async Python code.

1. Create `skills/python-async-testing/SKILL.md`:

   ```yaml
   ---
   name: python-async-testing
   description: Use when designing or reviewing tests for async Python code. Covers asyncio test patterns, fixtures for event loops, and mocking async dependencies.
   ---

   # Python Async Testing
   ...
   ```

2. Update `skills/brainstorming/SKILL.md` "Consulting specialist skills" - extend the python line:

   ```
   - python → `python-design-patterns`. Pull in `python-error-handling`, `python-testing-patterns`, `python-async-testing`, `async-python-patterns`, ... as relevant.
   ```

The subagent-driven-development routing doesn't need updates - it routes on domain, not on individual skills.

## Swap a vendored agent for your own

Example: replace the bundled `python-pro` with one tuned to your team's conventions.

1. Replace the content of `agents/python-pro.md` with yours. Keep the frontmatter `name: python-pro` and `model: inherit` so the routing tables still resolve.

2. **Update `scripts/sync-vendored.sh`.** The script's manifest currently re-copies `python-pro.md` from `wshobson/agents` on every sync run. To preserve your replacement:

   - Either remove the python-pro line from the manifest (your fork now owns this file fully)
   - Or add a post-copy step that re-applies your edits after the wshobson copy lands

The same pattern applies to any vendored skill you replace.

## Remove a specialist you don't use

Example: your fork doesn't do Rust work and you want rust-pro out.

1. Delete `agents/rust-pro.md`.

2. Delete the related skills if they're not shared with another domain:
   - `skills/rust-async-patterns/`
   - `skills/memory-safety-patterns/` is rust-only, safe to delete

3. Update `scripts/sync-vendored.sh`:
   - Remove the rust-pro entry from the manifest
   - Drop rust-pro from the post-copy override block

4. Update routing tables:
   - `skills/brainstorming/SKILL.md` - drop the rust line from "Consulting specialist skills"
   - `skills/subagent-driven-development/SKILL.md` - drop the rust row from the routing table


## Edit a vendored agent's behavior

Example: tune `python-pro` to recommend `httpx` instead of `requests` for new code.

1. Edit `agents/python-pro.md` directly. The system prompt is the prose after the frontmatter.

2. **Update `scripts/sync-vendored.sh`** to preserve your edits across syncs:

   - The script currently runs a single sed pass to override `model: opus` → `model: inherit`.
   - For your additional edits, either:
     - Remove python-pro from the manifest entirely (your fork now owns the file)
     - Add a second post-copy step that re-applies your specific edits


## Add a domain that isn't a language

Example: a `terraform` domain with terraform-pro agent and terraform-specific skills.

Mechanically the same as "add a specialist agent for a new language." The brainstorming skill's "Consulting specialist skills" section lists only languages in its examples; if your domain isn't language-shaped, the routing still works the same way.

## Sync from upstream wshobson

The bundled specialists come from `wshobson/agents`. To pull updates:

```bash
# Make sure your local checkout of wshobson/agents is current
cd ../agents && git pull

# Run the sync from your fork
cd ../superpowers-plus
./scripts/sync-vendored.sh

# Review the diff before committing
git diff
git diff --stat
```

If your local checkout is at a different path, set `WSHOBSON_AGENTS=/path/to/agents` or pass `--source /path/to/agents` to the script.

The sync script reapplies the `opus → inherit` override automatically. If you've made other edits to vendored files (per the recipes above), the sync may overwrite them - the script's output reports `UPDATED` for any file whose hash changed. Review the diff carefully before committing.

## Sync from upstream superpowers

If you also want to track upstream `obra/superpowers` for fixes to the workflow skills, that's a separate concern from vendored specialists. The fork has substantial divergence in `brainstorming`, `writing-plans`, and `subagent-driven-development`; cherry-picking specific upstream commits is usually safer than merging.

There's no automated tooling for this. Manual cherry-pick or selective merge, with the namespace verification check (no remaining `superpowers:` references in active files - see the namespace replace policy in past PRs for the pattern).

## Caveats

**The agent description shapes routing.** The controller infers which specialist matches an issue's domain by reading the agent's `description` field. Specific descriptions ("Use PROACTIVELY for Python 3.12+ async work") work better than generic ones ("Python expert"). When you add or edit agents, check that descriptions are disjoint enough that two agents won't both look like good matches for the same domain.

**Skills are loaded at session start.** Adding a new skill to your fork requires the user to reinstall the plugin (or reload from a fresh install) before the new skill appears in the skill registry. Existing sessions won't see it.

**Behavior-shaping content has higher risk.** The Red Flags tables, rationalization lists, and "human partner" language in the workflow skills (brainstorming, subagent-driven-development) were extensively tuned upstream by Jesse Vincent and the Prime Radiant team. Edits to those specifically have surprising effects on agent behavior. Test changes adversarially across multiple sessions before relying on them.

**Per-user shadowing is an alternative to forking.** If you only need a small change for your own use and don't want to maintain a fork, drop the file in `~/.claude/agents/` or `~/.claude/skills/`. Claude Code prefers user-scoped files over plugin-scoped ones, so a `~/.claude/agents/python-pro.md` overrides the bundled one without any fork edits. The routing tables will still reference `python-pro` and resolve to your version.

## If you plan to redistribute your fork publicly

The recipes above skip attribution and changelog updates because most forks are for personal use. If you intend to publish your fork (let other users install it), you'll also want to:

- Update `THIRD_PARTY.md` whenever you replace, edit, or remove vendored content. The current entries say "none" under Modifications; document what you changed.
- Update `CHANGELOG.md` for each shipped change. Keep a Changelog format, see existing entries.
- Tag releases (`vX.Y.Z`) so users have stable versions to install.

These exist for the upstream fork because it ships publicly. If your fork is private, skip them.
