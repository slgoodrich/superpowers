#!/usr/bin/env bash
# Structural tests for atomic-superpowers' additions to the workflow.
# Cheap grep-based checks that catch regressions if our additions get
# accidentally reverted or removed during an upstream sync.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

failed=0

assert_file_exists() {
    local path="$1" desc="$2"
    if [[ -f "$PLUGIN_DIR/$path" ]]; then
        echo "  [PASS] $desc"
    else
        echo "  [FAIL] $desc (missing: $path)"
        failed=$((failed + 1))
    fi
}

assert_grep() {
    local pattern="$1" file="$2" desc="$3"
    if grep -qE "$pattern" "$PLUGIN_DIR/$file" 2>/dev/null; then
        echo "  [PASS] $desc"
    else
        echo "  [FAIL] $desc (pattern '$pattern' not found in $file)"
        failed=$((failed + 1))
    fi
}

assert_grep_not() {
    local pattern="$1" file="$2" desc="$3"
    if grep -qE "$pattern" "$PLUGIN_DIR/$file" 2>/dev/null; then
        echo "  [FAIL] $desc (pattern '$pattern' should NOT be in $file)"
        failed=$((failed + 1))
    else
        echo "  [PASS] $desc"
    fi
}

echo "=== Structural tests: atomic-superpowers additions ==="
echo ""

echo "atomic-issues skill:"
assert_file_exists "skills/atomic-issues/SKILL.md" "skill file exists"
assert_grep "single coherent concern" "skills/atomic-issues/SKILL.md" "criteria documented"
assert_grep "single language or domain" "skills/atomic-issues/SKILL.md" "domain criterion documented"
assert_grep '"and" test' "skills/atomic-issues/SKILL.md" "and-test heuristic documented"
echo ""

echo "brainstorming integration:"
assert_grep "atomic-superpowers:atomic-issues" "skills/brainstorming/SKILL.md" "references atomic-issues skill"
assert_grep "Decompose into atomic issues" "skills/brainstorming/SKILL.md" "decomposition checklist step"
assert_grep "Consulting specialist skills" "skills/brainstorming/SKILL.md" "specialist consultation section"
assert_grep "writing-plans for the first issue" "skills/brainstorming/SKILL.md" "terminal state references first issue"
echo ""

echo "writing-plans per-issue:"
assert_grep "one atomic issue" "skills/writing-plans/SKILL.md" "per-issue input documented"
assert_grep "Issue Title" "skills/writing-plans/SKILL.md" "header template uses issue, not feature"
echo ""

echo "subagent-driven-development specialist routing:"
assert_grep "Specialist Routing" "skills/subagent-driven-development/SKILL.md" "routing section exists"
assert_grep "python-pro" "skills/subagent-driven-development/SKILL.md" "routing table includes python-pro"
assert_grep "general-purpose" "skills/subagent-driven-development/SKILL.md" "routing table includes general-purpose fallback"
assert_grep '\[SUBAGENT_TYPE\]' "skills/subagent-driven-development/implementer-prompt.md" "implementer-prompt has SUBAGENT_TYPE placeholder"
assert_grep '\[MODEL\]' "skills/subagent-driven-development/implementer-prompt.md" "implementer-prompt has MODEL placeholder"
assert_grep_not "general-purpose\)" "skills/subagent-driven-development/implementer-prompt.md" "implementer-prompt no longer hardcodes general-purpose"
echo ""

echo "vendored agents inherit-model override:"
for agent in python-pro typescript-pro rust-pro golang-pro; do
    assert_grep "^model: inherit$" "agents/$agent.md" "$agent uses model: inherit"
done
echo ""

echo "vendored content selection (sanity check):"
for agent in python-pro typescript-pro javascript-pro rust-pro golang-pro sql-pro; do
    assert_file_exists "agents/$agent.md" "$agent agent vendored"
done
echo ""

echo "============================================="
if [[ "$failed" -eq 0 ]]; then
    echo "STATUS: PASSED"
    exit 0
else
    echo "STATUS: FAILED ($failed checks failed)"
    exit 1
fi
