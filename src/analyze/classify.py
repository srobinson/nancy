#!/usr/bin/env python3
"""Classify parsed log events into categories and identify phase boundaries.

Categories:
  - navigation: Agent figuring out what's where (Read, Grep, Glob, etc.)
  - fmm_navigation: Sidecar-based navigation (read_symbol, Read *.fmm)
  - task_work: Agent doing actual work (Edit, Write, build/test commands)
  - boilerplate: Overhead (TodoWrite, nancy inbox/msg, Skill check-directives)
  - token_usage: Token accounting events (not tool calls)
  - other: Everything else

Phase boundary: "first edit" = first Edit or Write to a source file
(excludes ISSUES.md, config files, todo writes).
"""

import re

# Files that don't count as "real edits" for first-edit detection
# NOTE: Use negative lookahead for .nancy/ to exclude internal files
# but NOT experiment worktrees which live under .nancy/tasks/
_EXCLUDED_EDIT_PATTERNS = [
    r"ISSUES\.md$",
    r"COMPLETE$",
    r"\.nancy/(?!tasks/)",  # .nancy/ internal files, but not worktrees
    r"config\.json$",
    r"token-usage\.json$",
]
EXCLUDED_EDIT_RE = [re.compile(p) for p in _EXCLUDED_EDIT_PATTERNS]

# Bash commands that count as navigation
_NAV_BASH_PATTERNS = [
    r"^(ls|find|tree|wc|cat|head|tail|stat|file)\b",
    r"^git\s+(log|show|diff|blame|status)",
    r"^(rg|grep|ag|ack)\b",
]
NAV_BASH_RE = [re.compile(p, re.IGNORECASE) for p in _NAV_BASH_PATTERNS]

# Bash commands that count as task work
_TASK_BASH_PATTERNS = [
    r"^git\s+(add|commit|push|checkout|branch|merge|rebase|stash)",
    r"^(npm|pnpm|yarn|bun)\s+(test|build|run|install)",
    r"^(just|make|cargo|go)\s+(test|build|check|run)",
    r"^(pytest|jest|vitest|mocha)\b",
    r"^mkdir\b",
    r"^(cp|mv|rm)\b",
    r"^(tsc|eslint|prettier)\b",
    r"^(python|node|deno|bun)\b",
]
TASK_BASH_RE = [re.compile(p, re.IGNORECASE) for p in _TASK_BASH_PATTERNS]

# Bash commands that count as boilerplate
_BOILERPLATE_BASH_PATTERNS = [
    r"^nancy\s+(inbox|msg|archive|status)",
    r"^echo\s+.*done.*COMPLETE",
]
BOILERPLATE_BASH_RE = [re.compile(p, re.IGNORECASE) for p in _BOILERPLATE_BASH_PATTERNS]


def classify_events(events):
    """Add 'category' and 'phase' fields to each event.

    Returns the same events list, mutated with:
      - category: navigation | fmm_navigation | task_work | boilerplate | other
      - phase: nav | work (relative to first-edit boundary)
      - first_edit_seq: seq number of the first real edit (None if no edits)
    """
    first_edit_seq = _find_first_edit(events)

    for event in events:
        if event["type"] == "tool_call":
            event["category"] = _classify_tool_call(event)
        elif event["type"] == "token_usage":
            event["category"] = "token_usage"
        elif event["type"] == "init":
            event["category"] = "boilerplate"
        elif event["type"] == "user_message":
            event["category"] = "other"
        elif event["type"] == "assistant_text":
            event["category"] = "other"
        else:
            event["category"] = "other"

        if first_edit_seq is not None:
            event["phase"] = "nav" if event["seq"] < first_edit_seq else "work"
        else:
            event["phase"] = "nav"  # No edits = entire session was navigation

    return events, first_edit_seq


def _find_first_edit(events):
    """Find the seq of the first Edit/Write to a real source file."""
    for event in events:
        if event["type"] != "tool_call":
            continue
        if event["tool_name"] not in ("Edit", "Write"):
            continue
        fp = event.get("file_path", "") or ""
        if _is_excluded_file(fp):
            continue
        return event["seq"]
    return None


def _is_excluded_file(path):
    """Check if file path matches exclusion patterns."""
    return any(rx.search(path) for rx in EXCLUDED_EDIT_RE)


def _classify_tool_call(event):
    """Classify a single tool call event."""
    name = event["tool_name"]
    fp = event.get("file_path", "") or ""
    cmd = event.get("command", "") or ""

    # FMM navigation tools
    if name == "mcp__mcp-files__read_symbol":
        return "fmm_navigation"
    if name == "Read" and ".fmm" in fp:
        return "fmm_navigation"
    if name == "Bash" and "fmm" in cmd.lower() and ("search" in cmd.lower() or "grep" in cmd.lower()):
        return "fmm_navigation"

    # Boilerplate tools
    if name in ("TodoWrite", "KillShell"):
        return "boilerplate"
    if name == "Skill":
        skill = event.get("command", "")
        if skill and "check-directives" in skill:
            return "boilerplate"
        if skill and "nancy" in skill:
            return "boilerplate"
        return "other"
    if name == "Bash" and _matches_compiled(cmd, BOILERPLATE_BASH_RE):
        return "boilerplate"

    # Task work tools
    if name in ("Edit", "Write"):
        return "task_work"
    if name == "Bash" and _matches_compiled(cmd, TASK_BASH_RE):
        return "task_work"

    # Navigation tools
    if name in ("Read", "Grep", "Glob", "WebFetch"):
        return "navigation"
    if name == "Bash" and _matches_compiled(cmd, NAV_BASH_RE):
        return "navigation"
    if name == "Task":
        return "navigation"
    if name == "TaskOutput":
        return "navigation"

    # Linear MCP tools
    if name.startswith("mcp__linear"):
        return "boilerplate"

    # MCP context7
    if name.startswith("mcp__context7"):
        return "navigation"

    # Unclassified Bash — check if it's before first edit (likely nav)
    if name == "Bash":
        return "navigation"

    return "other"


def _matches_compiled(text, compiled_patterns):
    """Check if text matches any of the pre-compiled regex patterns."""
    return any(rx.search(text) for rx in compiled_patterns)


def compute_phase_summary(events, first_edit_seq):
    """Compute per-phase summaries from classified events.

    Returns dict with:
      - nav_phase: {tool_counts, token_totals, unique_files, event_count}
      - work_phase: {tool_counts, token_totals, unique_files, event_count}
      - totals: {token_totals, tool_calls, etc.}
    """
    nav_tools = []
    work_tools = []
    nav_tokens = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0}
    work_tokens = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0}
    total_tokens = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0}
    nav_files = set()
    work_files = set()
    nav_fmm_count = 0
    nav_raw_count = 0

    # (stream_message_start and assistant message can both report the same message)
    seen_message_ids = set()

    for event in events:
        if event["type"] == "token_usage":
            msg_id = event.get("message_id")
            # Deduplicate by message_id: we keep the first token_usage event we see
            # for a given message_id (typically the stream_message_start) and ignore
            # any later events with the same id, including assistant message updates.
            if msg_id and msg_id in seen_message_ids:
                continue
            if msg_id:
                seen_message_ids.add(msg_id)

            tokens = {
                "input": event["input_tokens"],
                "output": event["output_tokens"],
                "cache_create": event["cache_creation_input_tokens"],
                "cache_read": event["cache_read_input_tokens"],
            }
            for k in tokens:
                total_tokens[k] += tokens[k]

            if event["phase"] == "nav":
                for k in tokens:
                    nav_tokens[k] += tokens[k]
            else:
                for k in tokens:
                    work_tokens[k] += tokens[k]

        elif event["type"] == "tool_call":
            fp = event.get("file_path", "") or ""
            if event["phase"] == "nav":
                nav_tools.append(event)
                if fp:
                    nav_files.add(fp)
                if event["category"] == "fmm_navigation":
                    nav_fmm_count += 1
                elif event["category"] == "navigation":
                    nav_raw_count += 1
            else:
                work_tools.append(event)
                if fp:
                    work_files.add(fp)

    def _tool_counts(tool_list):
        counts = {}
        for t in tool_list:
            n = t["tool_name"]
            counts[n] = counts.get(n, 0) + 1
        return counts

    def _token_sum(d):
        return d["input"] + d["output"]

    return {
        "nav_phase": {
            "tool_counts": _tool_counts(nav_tools),
            "tool_call_count": len(nav_tools),
            "tokens": nav_tokens,
            "token_total": _token_sum(nav_tokens),
            "unique_files": sorted(nav_files),
            "unique_file_count": len(nav_files),
            "reads": sum(1 for t in nav_tools if t["tool_name"] == "Read"),
            "greps": sum(1 for t in nav_tools if t["tool_name"] in ("Grep", "Glob")),
            "fmm_lookups": nav_fmm_count,
            "raw_nav_lookups": nav_raw_count,
        },
        "work_phase": {
            "tool_counts": _tool_counts(work_tools),
            "tool_call_count": len(work_tools),
            "tokens": work_tokens,
            "token_total": _token_sum(work_tokens),
            "unique_files": sorted(work_files),
            "unique_file_count": len(work_files),
        },
        "totals": {
            "tokens": total_tokens,
            "token_total": _token_sum(total_tokens),
            "tool_calls": len(nav_tools) + len(work_tools),
        },
        "first_edit_seq": first_edit_seq,
        "has_edits": first_edit_seq is not None,
    }
