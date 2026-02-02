"""Shared test fixtures for src/analyze test suite."""

import json
import pytest


@pytest.fixture
def tmp_log_dir(tmp_path):
    """Provide a temporary directory for writing test log files."""
    return tmp_path


def write_ndjson(path, events):
    """Write a list of dicts as NDJSON to a file."""
    with open(path, "w", encoding="utf-8") as f:
        for event in events:
            f.write(json.dumps(event) + "\n")


def make_init_event(session_id="sess-1"):
    return {
        "type": "system",
        "subtype": "init",
        "session_id": session_id,
        "cwd": "/test",
        "model": "claude-opus-4-5-20251101",
        "tools": ["Read", "Edit", "Bash"],
        "mcp_servers": [],
    }


def make_assistant_event(content_blocks, session_id="sess-1", msg_id="msg-1",
                         input_tokens=100, output_tokens=50,
                         cache_creation=10, cache_read=20):
    return {
        "type": "assistant",
        "session_id": session_id,
        "message": {
            "id": msg_id,
            "content": content_blocks,
            "usage": {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "cache_creation_input_tokens": cache_creation,
                "cache_read_input_tokens": cache_read,
            },
        },
    }


def make_tool_use_block(name, tool_input, tool_id="tool-1"):
    return {"type": "tool_use", "name": name, "id": tool_id, "input": tool_input}


def make_text_block(text="Some text"):
    return {"type": "text", "text": text}


def make_user_event(session_id="sess-1"):
    return {"type": "user", "session_id": session_id}


def make_stream_message_start(session_id="sess-1", msg_id="msg-1",
                               input_tokens=100, output_tokens=0,
                               cache_creation=10, cache_read=20):
    return {
        "type": "stream_event",
        "session_id": session_id,
        "event": {
            "type": "message_start",
            "message": {
                "id": msg_id,
                "usage": {
                    "input_tokens": input_tokens,
                    "output_tokens": output_tokens,
                    "cache_creation_input_tokens": cache_creation,
                    "cache_read_input_tokens": cache_read,
                },
            },
        },
    }


def make_stream_message_delta(session_id="sess-1", output_tokens=50):
    return {
        "type": "stream_event",
        "session_id": session_id,
        "event": {
            "type": "message_delta",
            "usage": {"output_tokens": output_tokens},
        },
    }
