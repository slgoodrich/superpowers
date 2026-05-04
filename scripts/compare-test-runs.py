#!/usr/bin/env python3
"""
Compare a stock-superpowers full-pipeline test run with an atomic-superpowers
full-pipeline test run, side by side.

Usage:
  compare-test-runs.py STOCK_DIR ATOMIC_DIR [-o report.md]

STOCK_DIR and ATOMIC_DIR are the full-pipeline output directories produced
by tests/integration/test-full-pipeline.sh on each side. They contain the
turn-by-turn claude -p stream-json output and the resulting project tree.

The script walks the stream-json logs for tool invocations (Skill, Task,
TodoWrite, Edit, Write), reads the resulting project files, and renders
a markdown report covering:

  - Plugin metadata
  - Sequence of skill invocations
  - Subagent dispatches with subagent_type and description
  - TodoWrite usage (task list snapshots)
  - Review cycles (count of spec / code-quality reviewer dispatches)
  - Spec doc presence and atomic-issues section detection
  - Plan files written
  - Source files and their content
  - CLI smoke test outcome
  - pytest outcome

This is a one-shot, run-after-both-tests script. It does not invoke claude.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


# ---------------------------------------------------------------------------
# data extraction
# ---------------------------------------------------------------------------


@dataclass
class ToolCall:
    name: str
    input: dict
    turn_log: str


@dataclass
class RunData:
    label: str
    output_dir: Path
    project_dir: Path
    skills_in_order: list[str] = field(default_factory=list)
    subagent_dispatches: list[dict] = field(default_factory=list)  # {subagent_type, description, turn}
    todowrite_count: int = 0
    todowrite_snapshots: list[list[dict]] = field(default_factory=list)
    edit_count: int = 0
    write_count: int = 0
    spec_file: Path | None = None
    plan_files: list[Path] = field(default_factory=list)
    source_files: list[Path] = field(default_factory=list)
    test_files: list[Path] = field(default_factory=list)
    smoke_test_result: str = "not run"
    pytest_result: str = "not run"
    git_commits: list[str] = field(default_factory=list)


def parse_stream_json_file(path: Path) -> list[dict]:
    """Parse a stream-json file. Each line is one JSON object; bad lines skipped."""
    events: list[dict] = []
    if not path.exists():
        return events
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return events


def extract_tool_calls(events: list[dict], turn_log_name: str) -> list[ToolCall]:
    """Walk events for tool_use entries and yield ToolCall records."""
    calls: list[ToolCall] = []
    for ev in events:
        # The stream-json format wraps tool calls in assistant messages.
        # Look at message.content[*] where type == "tool_use".
        msg = ev.get("message")
        if not isinstance(msg, dict):
            continue
        for block in msg.get("content", []) or []:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                calls.append(ToolCall(
                    name=block.get("name", "<unknown>"),
                    input=block.get("input", {}) or {},
                    turn_log=turn_log_name,
                ))
    return calls


def collect_run(label: str, output_dir: Path) -> RunData:
    project_dir = output_dir / "project"
    run = RunData(label=label, output_dir=output_dir, project_dir=project_dir)

    # Walk turn JSON files in numeric order (01-, 02-, ...)
    turn_files = sorted(output_dir.glob("*.json"))
    for turn_file in turn_files:
        events = parse_stream_json_file(turn_file)
        for call in extract_tool_calls(events, turn_file.stem):
            if call.name == "Skill":
                skill = call.input.get("skill", "<unknown>")
                run.skills_in_order.append(f"{call.turn_log}: {skill}")
            elif call.name == "Task":
                run.subagent_dispatches.append({
                    "turn": call.turn_log,
                    "subagent_type": call.input.get("subagent_type", "general-purpose"),
                    "description": call.input.get("description", ""),
                })
            elif call.name == "TodoWrite":
                run.todowrite_count += 1
                todos = call.input.get("todos", [])
                if isinstance(todos, list):
                    run.todowrite_snapshots.append(todos)
            elif call.name == "Edit":
                run.edit_count += 1
            elif call.name == "Write":
                run.write_count += 1

    # Project artifacts
    if project_dir.is_dir():
        spec_dir = project_dir / "docs" / "superpowers" / "specs"
        if spec_dir.is_dir():
            specs = sorted(spec_dir.glob("*.md"))
            if specs:
                run.spec_file = specs[0]

        plan_dir = project_dir / "docs" / "superpowers" / "plans"
        if plan_dir.is_dir():
            run.plan_files = sorted(plan_dir.glob("*.md"))

        for path in project_dir.rglob("*.py"):
            if any(part.startswith(".") for part in path.parts):
                continue
            name = path.name
            if name.startswith("test_") or name.endswith("_test.py"):
                run.test_files.append(path)
            else:
                run.source_files.append(path)

    # Git commits
    git_log_path = project_dir / ".git"
    if git_log_path.is_dir():
        try:
            import subprocess
            res = subprocess.run(
                ["git", "log", "--oneline"],
                cwd=str(project_dir), capture_output=True, text=True, timeout=10,
            )
            if res.returncode == 0:
                run.git_commits = [line for line in res.stdout.splitlines() if line.strip()]
        except Exception:
            pass

    # Smoke and pytest results live alongside the turn logs in the run dir
    smoke_log = output_dir / "cli-smoke.txt"
    if smoke_log.exists():
        run.smoke_test_result = smoke_log.read_text(errors="replace")[:1200]

    pytest_log = output_dir / "pytest-output.txt"
    if pytest_log.exists():
        run.pytest_result = pytest_log.read_text(errors="replace")[:1500]

    return run


# ---------------------------------------------------------------------------
# rendering
# ---------------------------------------------------------------------------


def review_cycle_counts(dispatches: list[dict]) -> dict[str, int]:
    """Count how many times each named reviewer-style dispatch happened."""
    counts: dict[str, int] = {}
    for d in dispatches:
        desc = (d.get("description") or "").lower()
        if "spec" in desc and ("review" in desc or "compliance" in desc):
            counts["spec_compliance"] = counts.get("spec_compliance", 0) + 1
        elif "code" in desc and ("quality" in desc or "review" in desc):
            counts["code_quality"] = counts.get("code_quality", 0) + 1
        elif "final" in desc and "review" in desc:
            counts["final_review"] = counts.get("final_review", 0) + 1
    return counts


def render_section(title: str, body: str) -> str:
    return f"## {title}\n\n{body}\n\n"


def render_two_column(title: str, stock: str, atomic: str) -> str:
    out = [f"## {title}\n"]
    out.append("### Stock superpowers\n")
    out.append(stock if stock.strip() else "_(empty)_")
    out.append("\n")
    out.append("### atomic-superpowers\n")
    out.append(atomic if atomic.strip() else "_(empty)_")
    out.append("\n")
    return "\n".join(out)


def fenced(content: str, lang: str = "") -> str:
    return f"```{lang}\n{content}\n```"


def render_skill_sequence(run: RunData) -> str:
    if not run.skills_in_order:
        return "_(no skill invocations captured)_"
    lines = []
    for i, entry in enumerate(run.skills_in_order, 1):
        lines.append(f"{i}. `{entry}`")
    return "\n".join(lines)


def render_dispatches(run: RunData) -> str:
    if not run.subagent_dispatches:
        return "_(no Task dispatches captured)_"
    lines = []
    for i, d in enumerate(run.subagent_dispatches, 1):
        st = d.get("subagent_type", "general-purpose")
        desc = d.get("description", "")[:80]
        turn = d.get("turn", "")
        lines.append(f"{i}. `{st}` ({turn}) - {desc}")
    return "\n".join(lines)


def render_review_counts(run: RunData) -> str:
    counts = review_cycle_counts(run.subagent_dispatches)
    if not counts:
        return "_(no review-style dispatches detected)_"
    lines = []
    for k in ("spec_compliance", "code_quality", "final_review"):
        if k in counts:
            lines.append(f"- {k}: {counts[k]}")
    if not lines:
        return "_(none detected)_"
    return "\n".join(lines)


def render_spec(run: RunData) -> str:
    if not run.spec_file or not run.spec_file.exists():
        return "_(no spec doc found)_"
    content = run.spec_file.read_text(errors="replace")
    has_atomic = bool(re.search(r"atomic[ -]issue|## issues|### issue", content, re.IGNORECASE))
    note = "Has 'atomic issues' section: **YES**" if has_atomic else "Has 'atomic issues' section: no"
    excerpt = content[:3000]
    if len(content) > 3000:
        excerpt += "\n\n... (truncated)"
    return f"Path: `{run.spec_file}`\n\n{note}\n\n{fenced(excerpt, 'markdown')}"


def render_plans(run: RunData) -> str:
    if not run.plan_files:
        return "_(no plan files found)_"
    lines = [f"Count: {len(run.plan_files)}"]
    for path in run.plan_files:
        size = path.stat().st_size
        lines.append(f"- `{path.name}` ({size} bytes)")
    if len(run.plan_files) <= 3:
        lines.append("")
        for path in run.plan_files:
            lines.append(f"#### {path.name}\n")
            content = path.read_text(errors="replace")
            excerpt = content[:2000]
            if len(content) > 2000:
                excerpt += "\n\n... (truncated)"
            lines.append(fenced(excerpt, "markdown"))
            lines.append("")
    return "\n".join(lines)


def render_source_code(run: RunData) -> str:
    if not run.source_files:
        return "_(no source files found)_"
    lines = []
    for path in run.source_files[:5]:
        rel = path.relative_to(run.project_dir)
        lines.append(f"#### `{rel}`\n")
        content = path.read_text(errors="replace")
        lines.append(fenced(content, "python"))
        lines.append("")
    if len(run.source_files) > 5:
        lines.append(f"_(+{len(run.source_files) - 5} more source files)_")
    return "\n".join(lines)


def render_tests(run: RunData) -> str:
    if not run.test_files:
        return "_(no test files found)_"
    lines = []
    for path in run.test_files[:3]:
        rel = path.relative_to(run.project_dir)
        lines.append(f"#### `{rel}`\n")
        content = path.read_text(errors="replace")
        lines.append(fenced(content, "python"))
        lines.append("")
    return "\n".join(lines)


def render_commits(run: RunData) -> str:
    if not run.git_commits:
        return "_(no commits)_"
    return f"Count: {len(run.git_commits)}\n\n```\n" + "\n".join(run.git_commits) + "\n```"


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def build_report(stock: RunData, atomic: RunData) -> str:
    out: list[str] = []
    out.append("# Stock vs atomic-superpowers - Head-to-Head Test Report\n")
    out.append("")
    out.append(f"- **Stock output dir**: `{stock.output_dir}`")
    out.append(f"- **Atomic output dir**: `{atomic.output_dir}`")
    out.append("")
    out.append("---")
    out.append("")

    out.append("## Summary deltas\n")
    out.append("| Metric | Stock | atomic-superpowers |")
    out.append("|---|---|---|")
    out.append(f"| Skill invocations | {len(stock.skills_in_order)} | {len(atomic.skills_in_order)} |")
    out.append(f"| Subagent dispatches | {len(stock.subagent_dispatches)} | {len(atomic.subagent_dispatches)} |")
    out.append(f"| Plan files | {len(stock.plan_files)} | {len(atomic.plan_files)} |")
    out.append(f"| Source files | {len(stock.source_files)} | {len(atomic.source_files)} |")
    out.append(f"| Test files | {len(stock.test_files)} | {len(atomic.test_files)} |")
    out.append(f"| TodoWrite calls | {stock.todowrite_count} | {atomic.todowrite_count} |")
    out.append(f"| Edit calls | {stock.edit_count} | {atomic.edit_count} |")
    out.append(f"| Write calls | {stock.write_count} | {atomic.write_count} |")
    out.append(f"| Git commits | {len(stock.git_commits)} | {len(atomic.git_commits)} |")
    out.append("")

    # Specialist routing summary - the headline differentiator
    stock_subagent_types = sorted({d.get("subagent_type", "general-purpose") for d in stock.subagent_dispatches})
    atomic_subagent_types = sorted({d.get("subagent_type", "general-purpose") for d in atomic.subagent_dispatches})
    out.append("**Distinct subagent types dispatched:**")
    out.append(f"- Stock: {', '.join(stock_subagent_types) or 'none'}")
    out.append(f"- Atomic: {', '.join(atomic_subagent_types) or 'none'}")
    out.append("")

    out.append(render_two_column("Skill invocations (in order)",
                                  render_skill_sequence(stock),
                                  render_skill_sequence(atomic)))
    out.append(render_two_column("Subagent dispatches",
                                  render_dispatches(stock),
                                  render_dispatches(atomic)))
    out.append(render_two_column("Review cycle counts",
                                  render_review_counts(stock),
                                  render_review_counts(atomic)))
    out.append(render_two_column("Spec doc",
                                  render_spec(stock),
                                  render_spec(atomic)))
    out.append(render_two_column("Plan files",
                                  render_plans(stock),
                                  render_plans(atomic)))
    out.append(render_two_column("Source code",
                                  render_source_code(stock),
                                  render_source_code(atomic)))
    out.append(render_two_column("Test files",
                                  render_tests(stock),
                                  render_tests(atomic)))
    out.append(render_two_column("Git commits",
                                  render_commits(stock),
                                  render_commits(atomic)))
    out.append(render_two_column("CLI smoke test",
                                  fenced(stock.smoke_test_result),
                                  fenced(atomic.smoke_test_result)))
    out.append(render_two_column("pytest",
                                  fenced(stock.pytest_result),
                                  fenced(atomic.pytest_result)))

    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("stock_dir", help="full-pipeline output dir from stock-superpowers run")
    p.add_argument("atomic_dir", help="full-pipeline output dir from atomic-superpowers run")
    p.add_argument("-o", "--output", default=None,
                   help="output markdown file (default: stdout)")
    args = p.parse_args()

    stock_path = Path(args.stock_dir).resolve()
    atomic_path = Path(args.atomic_dir).resolve()

    if not stock_path.is_dir():
        print(f"error: stock dir not found: {stock_path}", file=sys.stderr)
        return 2
    if not atomic_path.is_dir():
        print(f"error: atomic dir not found: {atomic_path}", file=sys.stderr)
        return 2

    stock = collect_run("stock", stock_path)
    atomic = collect_run("atomic-superpowers", atomic_path)
    report = build_report(stock, atomic)

    if args.output:
        out_path = Path(args.output).resolve()
        out_path.write_text(report, encoding="utf-8")
        print(f"report written: {out_path}", file=sys.stderr)
    else:
        sys.stdout.write(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
