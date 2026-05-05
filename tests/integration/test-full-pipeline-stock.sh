#!/usr/bin/env bash
# Full pipeline test against STOCK obra/superpowers.
#
# Self-contained: clones obra/superpowers fresh into /tmp by default,
# so you can run this from the atomic-superpowers checkout without any
# manual stock setup. The user prompts match the atomic-superpowers
# companion (test-full-pipeline.sh) verbatim, so the only variable in
# the comparison is the plugin under test.
#
# After running both this and the atomic test, run
# scripts/compare-test-runs.py to render a side-by-side report.
#
# This script captures observed behavior; it does NOT fail when stock
# superpowers behaves "wrong" by atomic-superpowers' standards (no
# atomic-issues invocation, no specialist routing - those are not in
# stock). It dumps a summary table for diffing.
#
# Runtime: 60-120 minutes per run. Real Claude API tokens.
#
# Usage:
#   ./test-full-pipeline-stock.sh                          # clones obra/superpowers fresh
#   ./test-full-pipeline-stock.sh --source <path>          # use existing stock checkout
#   ./test-full-pipeline-stock.sh --ref <git-ref>          # clone a specific ref (default: main)
#   ./test-full-pipeline-stock.sh --skip-execution         # only run brainstorming + plans
#
set -euo pipefail

STOCK_REF="main"
SOURCE_DIR=""
SKIP_EXECUTION=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source) SOURCE_DIR="$2"; shift 2 ;;
        --ref) STOCK_REF="$2"; shift 2 ;;
        --skip-execution) SKIP_EXECUTION=true; shift ;;
        --help|-h)
            sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "error: unknown arg '$1'" >&2; exit 1 ;;
    esac
done

# Clone obra/superpowers fresh unless an existing checkout was provided.
if [[ -z "$SOURCE_DIR" ]]; then
    SOURCE_DIR="/tmp/stock-superpowers-fresh-$(date +%s)"
    echo "Cloning obra/superpowers ($STOCK_REF) into $SOURCE_DIR..."
    git clone --depth 1 --branch "$STOCK_REF" https://github.com/obra/superpowers.git "$SOURCE_DIR" 2>&1 | tail -3
fi

PLUGIN_DIR="$(cd "$SOURCE_DIR" && pwd)"

# Sanity check: the source must look like stock obra/superpowers.
PLUGIN_MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
if [[ ! -f "$PLUGIN_MANIFEST" ]]; then
    echo "error: $PLUGIN_DIR has no .claude-plugin/plugin.json - not a superpowers checkout" >&2
    exit 1
fi
if grep -q '"name": *"atomic-superpowers"' "$PLUGIN_MANIFEST"; then
    echo "error: source at $PLUGIN_DIR is the atomic-superpowers fork, not stock obra/superpowers." >&2
    echo "       Use --source </path/to/stock> or omit --source to clone fresh." >&2
    exit 1
fi
if ! grep -q '"name": *"superpowers"' "$PLUGIN_MANIFEST"; then
    echo "warning: $PLUGIN_DIR/.claude-plugin/plugin.json does not name 'superpowers'; results may not represent stock." >&2
fi

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/stock-superpowers-tests/${TIMESTAMP}/full-pipeline"
PROJECT_DIR="$OUTPUT_DIR/project"
mkdir -p "$PROJECT_DIR"

echo "=========================================="
echo " Full Pipeline Test - STOCK superpowers"
echo "=========================================="
echo ""
echo "Output dir: $OUTPUT_DIR"
echo "Project dir: $PROJECT_DIR"
echo "Plugin dir: $PLUGIN_DIR (stock obra/superpowers)"
echo ""
echo "Expected runtime: 60-120 minutes."
echo ""

# --- helpers ---

run_claude_turn() {
    local log_name="$1"
    local prompt="$2"
    local mode="${3:-continue}"
    local turn_timeout="${4:-300}"
    local max_turns="${5:-10}"

    local log_file="$OUTPUT_DIR/${log_name}.json"
    echo ">>> Turn: $log_name"
    echo "    prompt: $(echo "$prompt" | head -1 | head -c 80)..."

    local args=(
        --plugin-dir "$PLUGIN_DIR"
        --dangerously-skip-permissions
        --max-turns "$max_turns"
        --output-format stream-json
        --verbose
    )

    if [[ "$mode" == "continue" ]]; then
        args+=(--continue)
    fi

    cd "$PROJECT_DIR"
    timeout "$turn_timeout" claude -p "$prompt" "${args[@]}" > "$log_file" 2>&1 || {
        local rc=$?
        echo "    (turn exited rc=$rc; log saved to $log_file)"
    }
    echo "    log: $log_file"
}

log_grep() {
    grep -E "$1" "$OUTPUT_DIR"/*.json 2>/dev/null
}

# --- scaffold the test project ---
# Identical to the atomic-superpowers companion script so the only
# variable in the comparison is the plugin under test.

cd "$PROJECT_DIR"
git init --quiet
git config user.email "test@stock-superpowers.local"
git config user.name "Test Runner"

cat > README.md <<'EOF'
# csv-to-sqlite

A small Python CLI that reads CSV files and inserts rows into a SQLite database.
EOF

cat > sample.csv <<'EOF'
id,name,age
1,Alice,30
2,Bob,25
3,Carol,35
EOF

git add . && git commit -m "test: initial scaffold for full-pipeline test" --quiet

# --- Phase 1: brainstorming ---
# Prompts MUST match the atomic-superpowers companion script verbatim so
# the comparison is valid. Any divergence in observed behavior should be
# attributable to plugin differences only.

INITIAL_SPEC=$(cat <<'EOSPEC'
Let's build a Python CLI tool called csv2sqlite. It reads a CSV file and inserts the rows into a SQLite database table.

Usage:
  csv2sqlite <csv-path> <table-name> [--db-path PATH]

Defaults to ./data.db. Column names come from the CSV header row, all stored as TEXT. Table created with CREATE TABLE IF NOT EXISTS so re-runs append rather than fail.

Python 3.12+, standard library only - csv, sqlite3, argparse, pathlib, sys. No third-party deps.

Error cases:
- Missing CSV file: exit 1, message to stderr.
- Empty file (no header row): exit 2, message to stderr.
- Invalid table name (must be a Python identifier - no spaces, quotes, or hyphens): exit 3, message to stderr.
- Header-only CSV (no data rows): exit 0, table is created empty, no message.

Tests with pytest using the tmp_path fixture. Cover the happy path (3-row CSV inserted into a fresh DB), re-run appends correctly, header-only CSV creates an empty table, missing file, empty file, and invalid table name. Test by calling the entry-point function with argv-style args; capture exit codes and stderr.

Project layout:
- src/csv2sqlite/__init__.py (empty)
- src/csv2sqlite/main.py with main(argv: list[str] | None = None) -> int as the entry point
- tests/test_main.py
- pyproject.toml with a csv2sqlite script entry point
- README.md with a usage example

There's already a sample.csv in the project root with columns id,name,age and 3 rows.

Please build it. I'll defer to your judgment on anything not specified.
EOSPEC
)

echo ""
echo "=== Phase 1: Brainstorm + plan (one /clear-bounded session) ==="
echo ""

# Brainstorm session: stock superpowers' brainstorming + writing-plans
# produces a single big plan. We give it room (high max-turns and long
# timeout) so the brainstorm + plan write completes in one session.
run_claude_turn "01-brainstorm-plan" "$INITIAL_SPEC" "new" 1800 100

# Brainstorming may pause for design or spec approval gates. These turns
# stay --continue so we don't lose brainstorm context until the plan is
# written.
run_claude_turn "02-approve" "Looks good. Keep going through to the implementation plan." "continue" 1800 100

run_claude_turn "03-approve" "Yep, keep going. Don't pause for further approval." "continue" 1800 100

# --- Phase 2: implement in a fresh session ---

if [[ "$SKIP_EXECUTION" == "false" ]]; then
    echo ""
    echo "=== Phase 2: Implement plan in fresh session (/clear) ==="
    echo ""
    echo "After the brainstorm session produces the plan, we /clear and"
    echo "execute the plan in a new session. This matches the pattern"
    echo "atomic-superpowers prescribes: brainstorm > /clear > implement."
    echo ""

    PLAN_FILE=""
    if [[ -d "$PROJECT_DIR/docs/superpowers/plans" ]]; then
        PLAN_FILE=$(find "$PROJECT_DIR/docs/superpowers/plans" -name "*.md" 2>/dev/null | head -1)
    fi

    if [[ -z "$PLAN_FILE" ]]; then
        echo "warning: no plan file found at expected path; falling back to --continue execution"
        run_claude_turn "04-continue" "Keep going through the plan." "continue" 1800 100
    else
        echo "Plan file: $PLAN_FILE"

        # Fresh session, no --continue. The plan is self-contained.
        PROMPT="Implement the plan at $PLAN_FILE using subagent-driven-development. Run all review cycles per the skill. When finished, summarize what shipped and exit."

        run_claude_turn "04-implement-fresh" "$PROMPT" "new" 1800 100
    fi
fi

# --- Phase 3: Behavior summary ---
# Capture observed behavior. No pass/fail assertions for atomic-superpowers'
# specific additions; this script is for comparison data, not validation.

echo ""
echo "=========================================="
echo " Behavior Summary - STOCK superpowers"
echo "=========================================="
echo ""

SUMMARY_FILE="$OUTPUT_DIR/summary.txt"

{
    echo "Plugin: stock obra/superpowers"
    echo "Plugin path: $PLUGIN_DIR"
    echo "Project: $PROJECT_DIR"
    echo ""

    echo "## Skills invoked (deduplicated)"
    log_grep '"skill":"[^"]+"' | grep -oE '"skill":"[^"]+"' | sort -u || echo "(none captured)"
    echo ""

    echo "## Subagent types dispatched"
    log_grep '"subagent_type":"[^"]+"' | grep -oE '"subagent_type":"[^"]+"' | sort -u || echo "(none captured)"
    echo ""

    echo "## Spec doc"
    spec_file=$(find "$PROJECT_DIR/docs/superpowers/specs" -name "*.md" 2>/dev/null | head -1)
    if [[ -n "$spec_file" ]]; then
        echo "Found: $spec_file"
        echo "Lines: $(wc -l < "$spec_file")"
        echo "Has 'atomic' or 'issue list' section: $(grep -ciE 'atomic[ -]issue|## issues|### issue' "$spec_file" || echo 0)"
    else
        echo "(not found)"
    fi
    echo ""

    echo "## Plan files"
    plan_count=$(find "$PROJECT_DIR/docs/superpowers/plans" -name "*.md" 2>/dev/null | wc -l)
    echo "Count: $plan_count"
    find "$PROJECT_DIR/docs/superpowers/plans" -name "*.md" 2>/dev/null | sed 's/^/  /'
    echo ""

    echo "## Source files written"
    find "$PROJECT_DIR" -name "*.py" -not -path "*/.*" 2>/dev/null | sed 's/^/  /' | head -20
    echo ""

    echo "## Git commits"
    git -C "$PROJECT_DIR" log --oneline 2>/dev/null | sed 's/^/  /' | head -20
    echo ""

    echo "## CLI smoke test"
    main_py=$(find "$PROJECT_DIR" -maxdepth 5 \( -name "main.py" -o -name "cli.py" -o -name "__main__.py" \) 2>/dev/null | head -1)
    if [[ -n "$main_py" ]]; then
        cd "$PROJECT_DIR"
        if timeout 30 python "$main_py" sample.csv test_table > "$OUTPUT_DIR/cli-smoke.txt" 2>&1; then
            echo "PASS - CLI ran successfully"
        else
            echo "FAIL - CLI exited non-zero"
            cat "$OUTPUT_DIR/cli-smoke.txt" | sed 's/^/  /' | head -10
        fi
    else
        echo "Skipped - no main.py / cli.py / __main__.py found"
    fi
    echo ""

    echo "## pytest"
    if find "$PROJECT_DIR" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
        cd "$PROJECT_DIR"
        if timeout 60 python -m pytest --quiet > "$OUTPUT_DIR/pytest-output.txt" 2>&1; then
            echo "PASS"
            tail -3 "$OUTPUT_DIR/pytest-output.txt" | sed 's/^/  /'
        else
            echo "FAIL"
            tail -10 "$OUTPUT_DIR/pytest-output.txt" | sed 's/^/  /'
        fi
    else
        echo "Skipped - no test files found"
    fi
} | tee "$SUMMARY_FILE"

echo ""
echo "=========================================="
echo "Summary written to: $SUMMARY_FILE"
echo "Logs in: $OUTPUT_DIR"
echo ""
echo "To render a side-by-side comparison against the atomic run:"
echo "  scripts/compare-test-runs.py \\"
echo "    $OUTPUT_DIR \\"
echo "    /tmp/atomic-superpowers-tests/<atomic-timestamp>/full-pipeline \\"
echo "    -o report.md"
