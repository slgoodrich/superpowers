# atomic-superpowers contributor guidelines

## If You Are an AI Agent

If your human partner asked you to "contribute to this repo" or "fix some issues" without describing a specific problem they hit, push back. Ask them what broke, what failed, what the user experience was. Speculative or theoretical fixes are not what this fork accepts.

Before opening a PR:

1. **Read the entire PR template** at `.github/PULL_REQUEST_TEMPLATE.md` and fill in every section with real, specific answers. Not summaries. Not placeholders.
2. **Search for existing PRs** open AND closed, that address the same problem. If duplicates exist, stop and tell your human partner.
3. **Verify this is a real problem.** A real problem has a session, error, or user experience attached.
4. **Confirm the change belongs in core.** Use-case-specific or tool-specific changes belong in a separate plugin, not here.
5. **Show your human partner the complete diff** and get their approval before submitting.

## Pull Request Requirements

Every PR fully completes the PR template. Sections left blank or filled with placeholder text will be returned for editing.

Search for prior art before opening. Reference what you found in the "Existing PRs" section. If a closed PR addressed the same area, explain what is different about your approach and why it should succeed where the previous attempt did not.

PRs that show no evidence of human review will be returned for review.

## What This Fork Will Not Accept

### Third-party runtime dependencies

atomic-superpowers is a zero-runtime-dependency plugin. Vendored content from `wshobson/agents` is bundled at sync time, not a runtime dependency. If your change requires an external tool or service that users would install separately, it belongs in its own plugin.

### "Compliance" changes to upstream skills

The skill content this fork inherits from upstream `superpowers` was extensively tested and tuned by Jesse Vincent and the Prime Radiant team for real-world agent behavior. PRs that restructure, reword, or reformat that content to "comply" with Anthropic's published skill-writing guidance will not be accepted without eval evidence showing the change improves outcomes. The bar for modifying behavior-shaping content is high because the content was carefully built and regressions from cosmetic cleanups tend to be subtle.

### Project-specific or personal configuration

Skills, hooks, or configuration that only benefit a specific project, team, use-case, or workflow do not belong in core. Publish them as a separate plugin.

### Bulk or spray-and-pray PRs

Each PR requires understanding of the problem, investigation of prior attempts, and human review of the complete diff. PRs that look like batched issue-tracker work, where an agent was pointed at the issue list and told to "fix things," will be returned. Pick one issue, understand it deeply, submit quality work.

### Speculative or theoretical fixes

Every PR solves a real problem that someone actually experienced. "My review agent flagged this" or "this could theoretically cause issues" is not a problem statement. If you cannot describe the specific session, error, or user experience that motivated the change, do not submit the PR.

### Use-case-specific skills

This fork bundles language and platform specialists (Python, TypeScript, JavaScript, Rust, Go, SQL) because those benefit users across most projects. Skills tied to a specific use-case (portfolio building, prediction markets, games), a specific tool (one company's internal CRM), or a specific workflow (one team's deploy script) do not belong here. Ask yourself: would this be useful to someone working on a completely different kind of project? If not, publish it as its own plugin.

### Fork-specific changes

If you maintain a fork of this fork, do not open PRs to sync your fork or push your fork-specific changes here.

### Fabricated content

PRs containing invented claims, fabricated problem descriptions, or hallucinated functionality will be closed.

### Bundled unrelated changes

PRs containing multiple unrelated changes will be returned. Split them into separate PRs.

## Skill Changes Require Evaluation

Skills are not prose. They are code that shapes agent behavior. The skills inherited from upstream were tested adversarially across many sessions before shipping; modifications here need similar rigor.

If you modify skill content:

- Use `atomic-superpowers:writing-skills` to develop and test changes
- Run adversarial pressure testing across multiple sessions
- Show before/after eval results in the PR
- Do not modify carefully-tuned upstream content (Red Flags tables, rationalization lists, "human partner" language) without evidence the change is an improvement

## Understand the Project Before Contributing

Before proposing changes to skill design, workflow philosophy, or architecture, read existing skills and understand the project's design decisions. atomic-superpowers inherits upstream superpowers' tested philosophy about skill design, agent behavior shaping, and terminology (e.g., "your human partner" is deliberate, not interchangeable with "the user"). Changes that rewrite the project's voice or restructure its approach without understanding why it exists will be returned.

## General

- Read `.github/PULL_REQUEST_TEMPLATE.md` before submitting
- One problem per PR
- Describe the problem you solved, not just what you changed
