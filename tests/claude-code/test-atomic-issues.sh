#!/usr/bin/env bash
# Test: atomic-issues skill
# Verifies that the skill is loadable and Claude can describe its criteria.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: atomic-issues skill ==="
echo ""

# Test 1: Verify skill is recognized
echo "Test 1: Skill recognition..."

output=$(run_claude "What is the atomic-issues skill? Describe what makes an issue atomic." 30)

if assert_contains "$output" "atomic-issues\|atomic issue\|coherent concern" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "single.*concern\|coherent concern" "Mentions single concern criterion"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "language\|domain" "Mentions language/domain criterion"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify the "and" test is recognized
echo "Test 2: 'and' test heuristic..."

output=$(run_claude "In atomic-issues, what is the 'and' test? When does 'and' indicate two issues vs one?" 30)

if assert_contains "$output" "and\|conjunction" "Recognizes the and test"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "two\|distinct\|separate" "Mentions splitting two concerns"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 3: Verify integration with brainstorming
echo "Test 3: Workflow integration..."

output=$(run_claude "When does brainstorming invoke the atomic-issues skill?" 30)

if assert_contains "$output" "decompos\|after.*spec\|after.*approv" "Mentions decomposition after spec approval"; then
    : # pass
else
    exit 1
fi

echo ""
echo "=== All tests passed ==="
