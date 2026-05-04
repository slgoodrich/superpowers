---
name: atomic-issues
description: Use when decomposing a feature into shippable units. Defines the criteria that make an issue atomic. Required reading during brainstorming's decomposition step and by writing-plans which consumes one issue at a time.
---

# Atomic Issues

Reference for decomposing features into atomic, independently-shippable issues.

Used by `atomic-superpowers:brainstorming` during decomposition and by `atomic-superpowers:writing-plans`, which writes one plan per issue.

## What is an atomic issue?

An atomic issue:

- **Does not break the build.** The repository must remain green after the issue lands.
- **Leaves software in a shippable state.** Production-ready, deployable, no half-finished functionality reaching users.
- **Maps to a single push or commit (or close to it).** Not a hard rule, but a useful sizing check.

Plus one extension specific to this workflow:

- **Touches a single language or domain.** Python, TypeScript, JavaScript, Rust, Go, or SQL. This lets `subagent-driven-development` route the implementer to one specialist agent.

An atomic issue can have multiple acceptance criteria. What makes it atomic is that they are all about the same concern, not that there is only one of them.

## The "and" test

The hardest criterion to apply is "single coherent concern." A reliable test: write a one-sentence description of what this issue accomplishes. If it uses "and" to connect two distinct actions, outcomes, or user flows, you probably have two issues.

"And" connecting items inside a single concept does not count. "Name and address" is one profile; "title and body" is one post; "create and update" can be one persistence path. The test is about "and" between verbs, between outcomes, or between actors.

- "Users can log in with valid credentials" → one concern.
- "Users can log in and reset their password" → two concerns. Two distinct actions.
- "Users can log in and admins can see the user list" → two concerns. Two different actors.

Multiple acceptance criteria within one concern are normal:

> Issue: User login with valid credentials
> - User submits valid credentials → session is created, redirect to dashboard
> - User submits invalid credentials → 401 with generic error message
> - User exceeds 5 failed attempts in 10 minutes → temporary lockout
> - Session cookie has correct security attributes (httpOnly, secure, sameSite)

All four ACs are about the same login concern. They ship together, they review together, they make sense together.

## Single language or domain

Each issue touches one of the bundled domains: Python, TypeScript, JavaScript, Rust, Go, or SQL.

If a proposed issue meaningfully touches two domains, split it:

- "Create the Postgres schema and the Python repository class that uses it" → two issues.
- "Build the React component and the FastAPI endpoint it calls" → two issues.
- "Add the TypeScript client and the Go service it calls" → two issues.

The split usually creates a dependency: the second issue depends on the first.

### When languages overlap in one file

Some work is naturally cross-domain at the file level. A Python file with embedded SQL, a TypeScript file with inline GraphQL schema. The rule is not "no second domain anywhere in the file." The rule is "the primary work of this issue is in one domain."

- Issue is a Python function that runs one query → Python issue, with the SQL skill as supplemental context.
- Issue is primarily a Postgres migration that includes a small Python script to invoke it → SQL issue, with Python supplemental.
- Issue is a TypeScript component that consumes an existing API → TypeScript issue, with no backend-language work needed.
- Issue is a backend endpoint with a tiny TypeScript caller patched in for testing → backend-language issue (Python, Go, etc.), with TypeScript supplemental.

When it is unclear, ask: what is the specialist expertise this issue most needs? The answer names the domain.

## Shippability

The stability criteria (does not break the build, leaves software shippable) protect main from regressions.

Apply as a binary check at the end of decomposition:

- If you ship this issue alone, does the system still work?
- Are users protected from hitting half-built functionality?
- If "no, this only makes sense bundled with the next one," they are not actually two issues. They are one issue prematurely split.

## Dependencies

Atomic issues frequently have ordering constraints. These are declared explicitly, not implicit.

Don't declare a dependency unless the depending issue would actually break without the depended-on issue being done.

Independent issues (no shared dependencies) execute in dependency order, one plan at a time, sequential merge. Sequential execution + sequential merge is what lets the workflow handle file-level conflicts naturally: each subsequent issue rebases on the merged state of the previous one.

## Decomposition workflow

During brainstorming, after the design is agreed:

1. **Identify the work units.** Walk through the design and list every distinct piece of work. Don't worry about granularity yet. Just enumerate.

2. **Apply the atomicity checks.** For each unit, verify:
   - One coherent concern? (no "and" in the description)
   - One domain? (single bundled language)
   - Stable when shipped alone? (system still works, no half-built UX)
   - Maps to a single push or commit (or close to it)?

3. **Split units that fail any check.** A unit that fails atomicity becomes two or more units. Repeat the checks on the splits.

4. **Declare dependencies.** For each issue, list which other issues must ship first. Be conservative: only declare real ordering constraints.

5. **Validate the decomposition with the human partner.** Read back the issue list with scope and dependencies. The human is the final judge of whether the split matches the work they want done.

The output is an ordered list of atomic issues, each with title, scope, acceptance criteria, and dependencies.

## What atomic issues are not

Common mistakes worth naming explicitly:

**Atomic issues are not implementation steps.** "Create the file, write the function, add the test, run the linter" is not four issues. Those are the steps within one issue. Implementation steps live in the plan, not in the decomposition.

**Atomic issues are not the smallest possible work.** "Add a comment to one line" is too small to be a meaningful atomic issue. Atomicity is the floor of useful work units, not the floor of any change.

**Atomic issues are not always one file.** Touching three files for one coherent concern is fine. Touching one file for three unrelated concerns is not.

## Integration with the workflow

`atomic-superpowers:brainstorming` produces a spec that includes the decomposed issue list with dependencies.

`atomic-superpowers:writing-plans` takes one issue at a time and produces a plan file for that issue. The plan is the implementation detail for one atomic issue, not the whole feature.

`atomic-superpowers:subagent-driven-development` executes one plan at a time. Routes the implementer subagent to the specialist matching the issue's domain (inferred from plan content), with `general-purpose` as fallback.

The chain: feature → many atomic issues → one plan per issue → one specialist execution per plan → one review pass per plan.
