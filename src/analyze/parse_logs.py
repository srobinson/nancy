#!/usr/bin/env python3
"""Parse Nancy raw NDJSON logs into structured event streams.

Reads .log files (not .formatted.log) and extracts:
- Tool calls with name, arguments, file paths
- Per-message token usage (input, output, cache_creation, cache_read)
- Session boundaries (init events)
"""

import json
import sys
from pathlib import Path


def parse_log_file(path):
    """Parse a single raw .log file into structured events.

    Returns a list of events, each a dict with:
      - seq: int (ordering)
      - type: str (init | tool_call | token_usage | user_message | assistant_text)
      - Plus type-specific fields
    """
    events = []
    seq = 0

    with open(path) as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                raw = json.loads(line)
            except json.JSONDecodeError:
                continue

            evt_type = raw.get("type")
            session_id = raw.get("session_id")

            if evt_type == "system" and raw.get("subtype") == "init":
                events.append({
                    "seq": seq,
                    "type": "init",
                    "session_id": session_id,
                    "cwd": raw.get("cwd"),
                    "model": raw.get("model"),
                    "tools": raw.get("tools", []),
                    "mcp_servers": raw.get("mcp_servers", []),
                })
                seq += 1

            elif evt_type == "assistant":
                msg = raw.get("message", {})
                usage = msg.get("usage")
                content = msg.get("content", [])

                # Extract token usage from the assistant message itself
                if usage:
                    events.append({
                        "seq": seq,
                        "type": "token_usage",
                        "session_id": session_id,
                        "message_id": msg.get("id"),
                        "input_tokens": usage.get("input_tokens", 0),
                        "output_tokens": usage.get("output_tokens", 0),
                        "cache_creation_input_tokens": usage.get("cache_creation_input_tokens", 0),
                        "cache_read_input_tokens": usage.get("cache_read_input_tokens", 0),
                    })
                    seq += 1

                # Extract tool calls
                for block in content:
                    if block.get("type") == "tool_use":
                        tool_input = block.get("input", {})
                        events.append({
                            "seq": seq,
                            "type": "tool_call",
                            "session_id": session_id,
                            "tool_name": block.get("name"),
                            "tool_id": block.get("id"),
                            "arguments": tool_input,
                            "file_path": _extract_file_path(block.get("name"), tool_input),
                            "command": _extract_command(block.get("name"), tool_input),
                        })
                        seq += 1
                    elif block.get("type") == "text":
                        events.append({
                            "seq": seq,
                            "type": "assistant_text",
                            "session_id": session_id,
                            "text_length": len(block.get("text", "")),
                        })
                        seq += 1

            elif evt_type == "stream_event":
                event_data = raw.get("event", {})
                if event_data.get("type") == "message_start":
                    usage = event_data.get("message", {}).get("usage")
                    if usage:
                        events.append({
                            "seq": seq,
                            "type": "token_usage",
                            "session_id": session_id,
                            "source": "stream_message_start",
                            "message_id": event_data.get("message", {}).get("id"),
                            "input_tokens": usage.get("input_tokens", 0),
                            "output_tokens": usage.get("output_tokens", 0),
                            "cache_creation_input_tokens": usage.get("cache_creation_input_tokens", 0),
                            "cache_read_input_tokens": usage.get("cache_read_input_tokens", 0),
                        })
                        seq += 1
                # Skip message_delta — it only carries output_tokens which are
                # already reported by the assistant event. Including it would
                # double-count since message_delta has no message_id for dedup.

            elif evt_type == "user":
                events.append({
                    "seq": seq,
                    "type": "user_message",
                    "session_id": session_id,
                })
                seq += 1

    return events


def _extract_file_path(tool_name, args):
    """Pull file path from tool arguments based on tool name."""
    if tool_name in ("Read", "Edit", "Write"):
        return args.get("file_path")
    if tool_name == "Glob":
        return args.get("pattern")
    if tool_name == "Grep":
        return args.get("path")
    if tool_name == "mcp__mcp-files__read_symbol":
        paths = args.get("file_paths", [])
        return paths[0] if paths else None
    return None


def _extract_command(tool_name, args):
    """Pull command string from Bash-type tool calls."""
    if tool_name == "Bash":
        return args.get("command")
    if tool_name == "Skill":
        return args.get("skill")
    if tool_name == "Task":
        return args.get("prompt", "")[:200]
    return None


def parse_experiment_logs(log_dir):
    """Parse all iteration logs in a directory.

    Returns dict of {iteration_name: [events]} sorted by iteration order.
    Skips review iterations and non-.log files.
    """
    log_dir = Path(log_dir)
    iterations = {}

    for log_file in sorted(log_dir.glob("*.log")):
        name = log_file.stem
        # Skip non-raw logs
        if name.endswith(".formatted") or name in ("token-alerts", "watcher"):
            continue
        events = parse_log_file(log_file)
        iterations[name] = events

    return iterations


def main():
    if len(sys.argv) < 2:
        print("Usage: parse_logs.py <log_dir_or_file> [--json]", file=sys.stderr)
        sys.exit(1)

    path = Path(sys.argv[1])
    as_json = "--json" in sys.argv

    if path.is_file():
        events = parse_log_file(path)
        if as_json:
            json.dump(events, sys.stdout, indent=2)
        else:
            _print_summary({"single": events})
    elif path.is_dir():
        iterations = parse_experiment_logs(path)
        if as_json:
            json.dump(iterations, sys.stdout, indent=2)
        else:
            _print_summary(iterations)
    else:
        print(f"Error: {path} not found", file=sys.stderr)
        sys.exit(1)


def _print_summary(iterations):
    """Print a human-readable summary of parsed events."""
    for name, events in iterations.items():
        tool_calls = [e for e in events if e["type"] == "tool_call"]
        token_events = [e for e in events if e["type"] == "token_usage"]
        total_input = sum(e["input_tokens"] for e in token_events)
        total_output = sum(e["output_tokens"] for e in token_events)
        total_cache_create = sum(e["cache_creation_input_tokens"] for e in token_events)
        total_cache_read = sum(e["cache_read_input_tokens"] for e in token_events)

        tool_counts = {}
        for tc in tool_calls:
            n = tc["tool_name"]
            tool_counts[n] = tool_counts.get(n, 0) + 1

        print(f"\n{'='*60}")
        print(f"  {name}")
        print(f"{'='*60}")
        print(f"  Total events:    {len(events)}")
        print(f"  Tool calls:      {len(tool_calls)}")
        print(f"  Token events:    {len(token_events)}")
        print(f"  Input tokens:    {total_input:,}")
        print(f"  Output tokens:   {total_output:,}")
        print(f"  Cache create:    {total_cache_create:,}")
        print(f"  Cache read:      {total_cache_read:,}")
        print(f"\n  Tool breakdown:")
        for tool, count in sorted(tool_counts.items(), key=lambda x: -x[1]):
            print(f"    {tool:40s} {count}")


if __name__ == "__main__":
    main()
