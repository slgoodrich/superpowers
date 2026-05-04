#!/usr/bin/env bash
#
# sync-vendored.sh - copy specialist agents and skills from wshobson/agents
# into superpowers-plus. By convention, the local checkout is at ../dev-agents
# (renamed to avoid colliding with slgoodrich/agents); upstream of record is
# wshobson/agents.
#
# Usage:
#   sync-vendored.sh [--source <path>]
#
# Default source: $DEV_AGENTS or ../dev-agents (relative to this repo).
# Reports what was added, modified, or unchanged. Does not commit.
# Run after every wshobson update you want to absorb. Diff-review before commit.
#
# Source: https://github.com/wshobson/agents
# License: MIT (see THIRD_PARTY.md for attribution)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- args ---

SOURCE="${DEV_AGENTS:-$REPO_ROOT/../dev-agents}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "error: unknown arg '$1'" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$SOURCE" ]]; then
  echo "error: source dir not found: $SOURCE" >&2
  echo "       set DEV_AGENTS env var or pass --source <path>" >&2
  exit 1
fi

if [[ ! -d "$SOURCE/plugins" ]]; then
  echo "error: $SOURCE doesn't look like a dev-agents checkout (no plugins/ dir)" >&2
  exit 1
fi

# --- manifest ---
#
# Format: <source-relative-path-in-dev-agents>|<dest-relative-path-in-superpowers-plus>
# One entry per line. Comments (#) and blank lines ignored.

MANIFEST=$(cat <<'EOF'
# --- Agents (6) ---
plugins/python-development/agents/python-pro.md|agents/python-pro.md
plugins/javascript-typescript/agents/typescript-pro.md|agents/typescript-pro.md
plugins/javascript-typescript/agents/javascript-pro.md|agents/javascript-pro.md
plugins/systems-programming/agents/rust-pro.md|agents/rust-pro.md
plugins/systems-programming/agents/golang-pro.md|agents/golang-pro.md
plugins/database-design/agents/sql-pro.md|agents/sql-pro.md

# --- Python skills (16) ---
plugins/python-development/skills/async-python-patterns|skills/async-python-patterns
plugins/python-development/skills/python-anti-patterns|skills/python-anti-patterns
plugins/python-development/skills/python-background-jobs|skills/python-background-jobs
plugins/python-development/skills/python-code-style|skills/python-code-style
plugins/python-development/skills/python-configuration|skills/python-configuration
plugins/python-development/skills/python-design-patterns|skills/python-design-patterns
plugins/python-development/skills/python-error-handling|skills/python-error-handling
plugins/python-development/skills/python-observability|skills/python-observability
plugins/python-development/skills/python-packaging|skills/python-packaging
plugins/python-development/skills/python-performance-optimization|skills/python-performance-optimization
plugins/python-development/skills/python-project-structure|skills/python-project-structure
plugins/python-development/skills/python-resilience|skills/python-resilience
plugins/python-development/skills/python-resource-management|skills/python-resource-management
plugins/python-development/skills/python-testing-patterns|skills/python-testing-patterns
plugins/python-development/skills/python-type-safety|skills/python-type-safety
plugins/python-development/skills/uv-package-manager|skills/uv-package-manager

# --- JS/TS skills (4) ---
plugins/javascript-typescript/skills/javascript-testing-patterns|skills/javascript-testing-patterns
plugins/javascript-typescript/skills/modern-javascript-patterns|skills/modern-javascript-patterns
plugins/javascript-typescript/skills/nodejs-backend-patterns|skills/nodejs-backend-patterns
plugins/javascript-typescript/skills/typescript-advanced-types|skills/typescript-advanced-types

# --- Systems skills (3) ---
plugins/systems-programming/skills/go-concurrency-patterns|skills/go-concurrency-patterns
plugins/systems-programming/skills/memory-safety-patterns|skills/memory-safety-patterns
plugins/systems-programming/skills/rust-async-patterns|skills/rust-async-patterns

# --- SQL skills (1) ---
plugins/database-design/skills/postgresql|skills/postgresql
EOF
)

# --- copy ---

added=0
updated=0
unchanged=0
missing=0

while IFS='|' read -r src_rel dst_rel; do
  # skip comments and blanks
  src_rel="${src_rel%%#*}"
  src_rel="${src_rel%"${src_rel##*[![:space:]]}"}"
  [[ -z "$src_rel" ]] && continue
  [[ -z "${dst_rel:-}" ]] && continue

  src="$SOURCE/$src_rel"
  dst="$REPO_ROOT/$dst_rel"

  if [[ ! -e "$src" ]]; then
    printf '  MISSING: %s\n' "$src_rel"
    missing=$((missing + 1))
    continue
  fi

  # Capture pre-state for comparison
  if [[ -e "$dst" ]]; then
    pre_hash=$(find "$dst" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1)
  else
    pre_hash=""
  fi

  # Copy (handles both files and directories)
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
  else
    cp "$src" "$dst"
  fi

  # Compare post-state
  post_hash=$(find "$dst" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1)

  if [[ -z "$pre_hash" ]]; then
    printf '  ADDED:     %s\n' "$dst_rel"
    added=$((added + 1))
  elif [[ "$pre_hash" != "$post_hash" ]]; then
    printf '  UPDATED:   %s\n' "$dst_rel"
    updated=$((updated + 1))
  else
    printf '  unchanged: %s\n' "$dst_rel"
    unchanged=$((unchanged + 1))
  fi
done <<< "$MANIFEST"

echo ""
echo "Summary:"
printf '  added:     %d\n' "$added"
printf '  updated:   %d\n' "$updated"
printf '  unchanged: %d\n' "$unchanged"
printf '  missing:   %d\n' "$missing"
echo ""

if [[ "$missing" -gt 0 ]]; then
  echo "Some manifest entries are missing in source. Update wshobson checkout or fix the manifest."
  exit 1
fi

echo "Source: $SOURCE"
echo "Run 'git diff --stat' to review changes before committing."
