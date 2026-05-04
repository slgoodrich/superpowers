#!/usr/bin/env bash
# Full atomic-superpowers pipeline test.
#
# Exercises the complete workflow end-to-end:
#   brainstorming -> atomic-issues decomposition -> writing-plans (per issue)
#   -> subagent-driven-development (with internal reviews) -> per-issue commits
#
# Test feature: a Python script that reads a CSV file and inserts rows into
# a SQLite database, with a small CLI (csv path + table name as args). The
# feature is deliberately mixed-domain (SQL + Python) so specialist routing
# can be observed (sql-pro for the schema issue, python-pro for the rest).
#
# Verifies:
#   - brainstorming invokes atomic-issues skill (decomposition)
#   - brainstorming consults specialist skills (python-design-patterns,
#     postgresql, etc.)
#   - spec doc has an Atomic Issues section
#   - per-issue plan files are produced (one per atomic issue)
#   - subagent-driven-development dispatches the matching specialist agent
#     for each issue (sql-pro for the SQL schema issue, python-pro for the
#     Python issues), with general-purpose only as a fallback
#   - the spec compliance, code quality, and final code review subagents
#     run as part of subagent-driven-development
#   - resulting code actually works (pytest passes against the resulting CLI)
#
# Runtime: 60-120 minutes per run. Real Claude API tokens. Run on demand,
# not per PR.
#
# Usage:
#   ./test-full-pipeline.sh
#   ./test-full-pipeline.sh --skip-execution    # only run brainstorming + plans
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKIP_EXECUTION=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-execution) SKIP_EXECUTION=true; shift ;;
        --help|-h)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "error: unknown arg '$1'" >&2; exit 1 ;;
    esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/atomic-superpowers-tests/${TIMESTAMP}/full-pipeline"
PROJECT_DIR="$OUTPUT_DIR/project"
mkdir -p "$PROJECT_DIR"

echo "=========================================="
echo " Full Pipeline Integration Test"
echo "=========================================="
echo ""
echo "Output dir: $OUTPUT_DIR"
echo "Project dir: $PROJECT_DIR"
echo "Plugin dir: $PLUGIN_DIR"
echo ""
echo "Phases:"
echo "  1. Brainstorming + atomic-issue decomposition"
echo "  2. Writing-plans for first issue"
echo "  3. Subagent-driven-development for first issue"
echo "  4. Repeat 2 + 3 for remaining issues"
echo "  5. Verify resulting code works"
echo ""
echo "Expected runtime: 60-120 minutes."
echo ""

# --- helpers ---

# Run a claude turn. Captures stream-json output. Long timeout for SDD turns.
# Usage: run_claude_turn <log-name> <prompt> [<continue|new>] [<timeout-seconds>] [<max-turns>]
run_claude_turn() {
    local log_name="$1"
    local prompt="$2"
    local mode="${3:-continue}"   # "continue" or "new"
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

# Search across all session logs for a JSON pattern.
# Usage: log_grep <pattern>
log_grep() {
    grep -E "$1" "$OUTPUT_DIR"/*.json 2>/dev/null
}

# --- scaffold the test project ---

cd "$PROJECT_DIR"
git init --quiet
git config user.email "test@atomic-superpowers.local"
git config user.name "Test Runner"

# Empty starting state. Brainstorming will guide what gets built.
cat > README.md <<'EOF'
# csv-to-sqlite

A small Python CLI that reads CSV files and inserts rows into a SQLite database.
EOF

# Provide a sample CSV the resulting CLI can be tested against.
cat > sample.csv <<'EOF'
id,name,age
1,Alice,30
2,Bob,25
3,Carol,35
EOF

git add . && git commit -m "test: initial scaffold for full-pipeline test" --quiet

# --- Phase 1: brainstorming + decomposition ---

echo ""
echo "=== Phase 1: Brainstorming + atomic-issue decomposition ==="
echo ""

INITIAL_SPEC=$(cat <<'EOSPEC'
Build a small Python CLI tool. I want this fully designed and built using the atomic-superpowers workflow: brainstorming -> atomic-issue decomposition -> writing-plans -> subagent-driven-development. Below is the complete specification. Every design decision is locked. Skip clarifying questions; proceed to propose the approach, present the design, write the spec, decompose into atomic issues, and execute.

PURPOSE
- A CLI tool that reads a CSV file and inserts each row into a SQLite database table.
- Invocation: `csv2sqlite <csv-path> <table-name> [--db-path PATH]`
- Column names come from the CSV header row; all columns stored as TEXT.
- Re-runs append (no deduplication).

CONSTRAINTS
- Python 3.12+. Standard library only: csv, sqlite3, argparse, pathlib, sys.
- Default --db-path is ./data.db (relative to the working directory).
- The table is created with `CREATE TABLE IF NOT EXISTS` so re-runs work.
- The table name must be a Python identifier (validated before use; rejects names with spaces, quotes, or non-alphanumeric/underscore characters).

ERROR HANDLING
- Missing CSV file: exit 1, message to stderr.
- Empty CSV (no header row): exit 2, message to stderr.
- Invalid table name (fails identifier check): exit 3, message to stderr.
- Header-only CSV (no data rows): exit 0 silently, table is created empty.
- Other DB errors propagate naturally and the script exits non-zero.

TESTING
- pytest. Use the `tmp_path` fixture for filesystem isolation.
- Test cases:
  1. Happy path: 3-row CSV inserted into a fresh DB, all rows present.
  2. Re-run appends: running twice doubles the rows.
  3. Header-only CSV: table created, 0 rows, exit 0.
  4. Missing CSV file: exit 1.
  5. Empty file (zero bytes): exit 2.
  6. Invalid table name (space, quote, hyphen): exit 3.
- Test by importing the module's entry-point function and calling it with argv-equivalent args, capturing exit codes and stderr.

PROJECT STRUCTURE
- `pyproject.toml`: minimal packaging metadata, defines a `csv2sqlite` script entry point pointing at the main function.
- `src/csv2sqlite/__init__.py`: empty.
- `src/csv2sqlite/main.py`: contains `main(argv: list[str] | None = None) -> int` (the entry point) plus the CSV-to-SQLite logic.
- `tests/test_main.py`: the pytest cases above.
- `README.md`: brief usage example.

ATOMIC-ISSUES CRITERIA REMINDER
- Single coherent concern, single language or domain, shippable alone.
- Use atomic-superpowers:atomic-issues for the decomposition rules.
- Decompose this work yourself based on the spec above; do not ask me which issues to create.

ROUTING REMINDER
- For each plan, route the implementer subagent to the matching specialist agent per atomic-superpowers:subagent-driven-development's Specialist Routing section. SQL work routes to sql-pro. Python work routes to python-pro.

NO VISUAL COMPANION needed - skip the offer.

Project context: empty directory with a README.md and a sample.csv (id,name,age columns).

Please proceed through the entire workflow without further clarifying questions. Where the spec is silent, use idiomatic Python defaults. Keep it simple.
EOSPEC
)

run_claude_turn "01-idea-with-full-spec" "$INITIAL_SPEC" "new" 300 8

run_claude_turn "02-approve-design" "Approach and design look good. Proceed: write the spec doc, do the spec self-review, decompose into atomic issues per atomic-superpowers:atomic-issues, and append the issue list to the spec doc." "continue" 300 8

run_claude_turn "03-approve-spec" "Spec and decomposition look good. Proceed with the first atomic issue: write its plan, then execute via atomic-superpowers:subagent-driven-development with the matching specialist agent (per the Specialist Routing section)." "continue" 300 8

# --- Phase 2: per-issue execution ---
# After turn 04, the workflow is in writing-plans/SDD for the first issue.
# We continue with confirmation turns to keep it moving through subsequent
# issues. SDD turns get a much longer timeout because they dispatch
# subagents and run review loops.

if [[ "$SKIP_EXECUTION" == "false" ]]; then
    echo ""
    echo "=== Phase 2: Per-issue execution loop ==="
    echo ""

    # Three issues expected. SDD per issue can take 15-30 minutes (subagent
    # dispatches + spec compliance review + code quality review + fixes).
    # Each "continue with next issue" turn waits up to 30 minutes.

    run_claude_turn "04-execute" "Continue. Execute the first issue's plan via subagent-driven-development through all reviews until the issue's PR-ready state. Then move to the next issue: write its plan, execute it, all the way through. Continue until all decomposed atomic issues are complete." "continue" 1800 50

    # If turn 04 hit max-turns or timeout before finishing all issues,
    # nudge it forward.
    run_claude_turn "05-continue" "Continue with the remaining issues. If the previous one is complete, write the plan for the next atomic issue and execute it." "continue" 1800 50

    run_claude_turn "06-finalize" "Continue with any remaining issues. If everything is done, summarize what was built." "continue" 1800 50
fi

# --- Phase 3: Verification ---

echo ""
echo "=========================================="
echo " Verification"
echo "=========================================="
echo ""

failed=0

assert() {
    local desc="$1"; local cond_result="$2"
    if [[ "$cond_result" == "true" ]]; then
        echo "  [PASS] $desc"
    else
        echo "  [FAIL] $desc"
        failed=$((failed + 1))
    fi
}

# 1. Brainstorming invoked atomic-issues
echo "Phase 1 verification:"
if log_grep '"skill":"atomic-superpowers:atomic-issues"' >/dev/null; then
    assert "atomic-issues skill was invoked during brainstorming" "true"
else
    assert "atomic-issues skill was invoked during brainstorming" "false"
fi

# 2. Brainstorming consulted at least one Python specialist skill
if log_grep '"skill":"atomic-superpowers:(python-design-patterns|python-error-handling|python-testing-patterns|python-project-structure)"' >/dev/null; then
    assert "Python specialist skill consulted" "true"
else
    assert "Python specialist skill consulted" "false"
fi

# 3. Spec doc was created with atomic-issues section
spec_file=$(find "$PROJECT_DIR/docs/superpowers/specs" -name "*.md" 2>/dev/null | head -1)
if [[ -n "$spec_file" ]]; then
    assert "spec doc was written ($spec_file)" "true"
    if grep -qiE "atomic[ -]issue|## issues|### issue" "$spec_file"; then
        assert "spec contains atomic-issue list section" "true"
    else
        assert "spec contains atomic-issue list section" "false"
    fi
else
    assert "spec doc was written" "false"
    assert "spec contains atomic-issue list section" "false"
fi

echo ""
echo "Phase 2/3 verification (writing-plans + SDD):"

# 4. At least one per-issue plan was created
plan_count=$(find "$PROJECT_DIR/docs/superpowers/plans" -name "*.md" 2>/dev/null | wc -l)
if [[ "$plan_count" -ge 1 ]]; then
    assert "per-issue plan(s) written ($plan_count plans)" "true"
else
    assert "per-issue plan(s) written" "false"
fi

# 5. subagent-driven-development was invoked
if log_grep '"skill":"atomic-superpowers:subagent-driven-development"' >/dev/null; then
    assert "subagent-driven-development invoked" "true"
else
    assert "subagent-driven-development invoked" "false"
fi

# 6. Specialist subagent was dispatched (python-pro, sql-pro, or both)
if log_grep '"subagent_type":"(python-pro|sql-pro)"' >/dev/null; then
    assert "specialist subagent dispatched (python-pro or sql-pro)" "true"
    log_grep '"subagent_type":"[a-z-]+"' | grep -oE '"subagent_type":"[a-z-]+"' | sort -u | sed 's/^/    /'
else
    assert "specialist subagent dispatched (python-pro or sql-pro)" "false"
fi

# 7. Review subagents ran (spec compliance + code quality)
if log_grep 'spec.compliance|spec.reviewer' >/dev/null; then
    assert "spec compliance reviewer ran" "true"
else
    assert "spec compliance reviewer ran" "false"
fi
if log_grep 'code.quality.reviewer|code.review' >/dev/null; then
    assert "code quality reviewer ran" "true"
else
    assert "code quality reviewer ran" "false"
fi

echo ""
echo "Phase 5 verification (resulting code works):"

# 8. Python source exists
if find "$PROJECT_DIR" -name "*.py" -not -path "*/.*" 2>/dev/null | head -1 | grep -q .; then
    assert "Python source files were written" "true"
else
    assert "Python source files were written" "false"
fi

# 9. Multiple commits across issues
commit_count=$(git -C "$PROJECT_DIR" log --oneline 2>/dev/null | wc -l)
if [[ "$commit_count" -ge 4 ]]; then  # initial + at least 3 issue commits
    assert "multiple commits ($commit_count total)" "true"
else
    assert "multiple commits across issues ($commit_count, expected >= 4)" "false"
fi

# 10. Functional smoke test - try running the resulting CLI
if find "$PROJECT_DIR" -name "*.py" -not -path "*/test_*" -not -path "*/tests/*" 2>/dev/null | head -1 | grep -q .; then
    main_py=$(find "$PROJECT_DIR" -maxdepth 3 -name "main.py" -o -name "cli.py" -o -name "__main__.py" 2>/dev/null | head -1)
    if [[ -n "$main_py" ]]; then
        cd "$PROJECT_DIR"
        if timeout 30 python "$main_py" sample.csv test_table > /tmp/cli-output.txt 2>&1 && [[ -f *.db || -f *.sqlite ]]; then
            assert "CLI runs end-to-end without error" "true"
        else
            assert "CLI runs end-to-end without error" "false"
            cat /tmp/cli-output.txt | sed 's/^/    /'
        fi
    fi
fi

# 11. Tests run and pass
if find "$PROJECT_DIR" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
    cd "$PROJECT_DIR"
    if timeout 60 python -m pytest --quiet > /tmp/pytest-output.txt 2>&1; then
        assert "pytest passes" "true"
    else
        assert "pytest passes" "false"
        cat /tmp/pytest-output.txt | sed 's/^/    /' | head -30
    fi
fi

# --- summary ---

echo ""
echo "=========================================="
if [[ "$failed" -eq 0 ]]; then
    echo " STATUS: PASSED"
    echo "=========================================="
    echo ""
    echo "All pipeline phases verified end-to-end."
    echo ""
    echo "Logs: $OUTPUT_DIR"
    echo "Project: $PROJECT_DIR"
    exit 0
else
    echo " STATUS: FAILED ($failed checks failed)"
    echo "=========================================="
    echo ""
    echo "Logs: $OUTPUT_DIR"
    echo "Project: $PROJECT_DIR"
    exit 1
fi
