#!/usr/bin/env bash
# Structural tests for superpowers-plus' additions to the workflow.
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

echo "=== Structural tests: superpowers-plus additions ==="
echo ""

echo "brainstorming integration:"
assert_grep "Consulting specialist skills" "skills/brainstorming/SKILL.md" "specialist consultation section"
assert_grep "invoke writing-plans" "skills/brainstorming/SKILL.md" "terminal state invokes writing-plans"
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
