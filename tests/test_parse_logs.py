"""Tests for src/analyze/parse_logs.py — NDJSON parsing and event extraction."""

from src.analyze.parse_logs import parse_log_file, parse_experiment_logs, _extract_file_path, _extract_command
from tests.conftest import (
    write_ndjson, make_init_event, make_assistant_event, make_tool_use_block,
    make_text_block, make_user_event, make_stream_message_start,
    make_stream_message_delta,
)


class TestParseLogFile:
    def test_empty_file(self, tmp_path):
        log = tmp_path / "empty.log"
        log.write_text("")
        assert parse_log_file(log) == []

    def test_malformed_json_lines_skipped(self, tmp_path):
        log = tmp_path / "bad.log"
        log.write_text("not json\n{broken\n")
        assert parse_log_file(log) == []

    def test_blank_lines_skipped(self, tmp_path):
        log = tmp_path / "blank.log"
        log.write_text("\n\n  \n")
        assert parse_log_file(log) == []

    def test_init_event(self, tmp_path):
        log = tmp_path / "init.log"
        write_ndjson(log, [make_init_event()])
        events = parse_log_file(log)
        assert len(events) == 1
        assert events[0]["type"] == "init"
        assert events[0]["seq"] == 0
        assert events[0]["session_id"] == "sess-1"
        assert events[0]["model"] == "claude-opus-4-5-20251101"

    def test_assistant_with_tool_call(self, tmp_path):
        log = tmp_path / "tool.log"
        tool_block = make_tool_use_block("Read", {"file_path": "/src/main.py"})
        assistant = make_assistant_event([tool_block], msg_id="msg-10")
        write_ndjson(log, [assistant])
        events = parse_log_file(log)
        # Should produce: token_usage + tool_call
        types = [e["type"] for e in events]
        assert "token_usage" in types
        assert "tool_call" in types
        tc = next(e for e in events if e["type"] == "tool_call")
        assert tc["tool_name"] == "Read"
        assert tc["file_path"] == "/src/main.py"

    def test_assistant_text_block(self, tmp_path):
        log = tmp_path / "text.log"
        text_block = make_text_block("Hello world")
        assistant = make_assistant_event([text_block])
        write_ndjson(log, [assistant])
        events = parse_log_file(log)
        text_evt = next(e for e in events if e["type"] == "assistant_text")
        assert text_evt["text_length"] == 11

    def test_token_usage_from_assistant(self, tmp_path):
        log = tmp_path / "tokens.log"
        assistant = make_assistant_event(
            [], msg_id="msg-5", input_tokens=500, output_tokens=200,
            cache_creation=30, cache_read=100,
        )
        write_ndjson(log, [assistant])
        events = parse_log_file(log)
        tok = next(e for e in events if e["type"] == "token_usage")
        assert tok["input_tokens"] == 500
        assert tok["output_tokens"] == 200
        assert tok["cache_creation_input_tokens"] == 30
        assert tok["cache_read_input_tokens"] == 100
        assert tok["message_id"] == "msg-5"

    def test_stream_message_start(self, tmp_path):
        log = tmp_path / "stream.log"
        stream = make_stream_message_start(msg_id="msg-20", input_tokens=300)
        write_ndjson(log, [stream])
        events = parse_log_file(log)
        assert len(events) == 1
        assert events[0]["type"] == "token_usage"
        assert events[0]["input_tokens"] == 300

    def test_message_delta_skipped(self, tmp_path):
        """message_delta events should NOT produce token_usage events."""
        log = tmp_path / "delta.log"
        delta = make_stream_message_delta(output_tokens=999)
        write_ndjson(log, [delta])
        events = parse_log_file(log)
        assert len(events) == 0

    def test_user_event(self, tmp_path):
        log = tmp_path / "user.log"
        write_ndjson(log, [make_user_event()])
        events = parse_log_file(log)
        assert len(events) == 1
        assert events[0]["type"] == "user_message"

    def test_sequential_ordering(self, tmp_path):
        log = tmp_path / "multi.log"
        write_ndjson(log, [
            make_init_event(),
            make_user_event(),
            make_assistant_event([make_tool_use_block("Grep", {"pattern": "foo"})], msg_id="msg-a"),
        ])
        events = parse_log_file(log)
        seqs = [e["seq"] for e in events]
        assert seqs == sorted(seqs)
        assert len(set(seqs)) == len(seqs)  # all unique

    def test_multiple_tool_calls_in_one_message(self, tmp_path):
        log = tmp_path / "multi_tools.log"
        blocks = [
            make_tool_use_block("Read", {"file_path": "/a.py"}, tool_id="t1"),
            make_tool_use_block("Grep", {"pattern": "x", "path": "/src"}, tool_id="t2"),
        ]
        write_ndjson(log, [make_assistant_event(blocks, msg_id="msg-b")])
        events = parse_log_file(log)
        tool_calls = [e for e in events if e["type"] == "tool_call"]
        assert len(tool_calls) == 2
        assert tool_calls[0]["tool_name"] == "Read"
        assert tool_calls[1]["tool_name"] == "Grep"


class TestExtractFilePath:
    def test_read(self):
        assert _extract_file_path("Read", {"file_path": "/foo.py"}) == "/foo.py"

    def test_edit(self):
        assert _extract_file_path("Edit", {"file_path": "/bar.ts"}) == "/bar.ts"

    def test_write(self):
        assert _extract_file_path("Write", {"file_path": "/baz.md"}) == "/baz.md"

    def test_glob(self):
        assert _extract_file_path("Glob", {"pattern": "**/*.py"}) == "**/*.py"

    def test_grep(self):
        assert _extract_file_path("Grep", {"path": "/src"}) == "/src"

    def test_read_symbol(self):
        assert _extract_file_path("mcp__mcp-files__read_symbol", {"file_paths": ["/x.ts"]}) == "/x.ts"

    def test_read_symbol_empty(self):
        assert _extract_file_path("mcp__mcp-files__read_symbol", {"file_paths": []}) is None

    def test_unknown_tool(self):
        assert _extract_file_path("Bash", {"command": "ls"}) is None


class TestExtractCommand:
    def test_bash(self):
        assert _extract_command("Bash", {"command": "git status"}) == "git status"

    def test_skill(self):
        assert _extract_command("Skill", {"skill": "commit"}) == "commit"

    def test_task_truncates(self):
        long_prompt = "x" * 300
        result = _extract_command("Task", {"prompt": long_prompt})
        assert len(result) == 200

    def test_unknown(self):
        assert _extract_command("Read", {"file_path": "/x"}) is None


class TestParseExperimentLogs:
    def test_skips_formatted_logs(self, tmp_path):
        write_ndjson(tmp_path / "iter1.log", [make_init_event()])
        (tmp_path / "iter1.formatted.log").write_text("formatted data")
        iters = parse_experiment_logs(tmp_path)
        assert "iter1" in iters
        assert "iter1.formatted" not in iters

    def test_skips_non_log_files(self, tmp_path):
        write_ndjson(tmp_path / "iter1.log", [make_init_event()])
        (tmp_path / "notes.txt").write_text("notes")
        iters = parse_experiment_logs(tmp_path)
        assert list(iters.keys()) == ["iter1"]

    def test_skips_special_logs(self, tmp_path):
        write_ndjson(tmp_path / "token-alerts.log", [make_init_event()])
        write_ndjson(tmp_path / "watcher.log", [make_init_event()])
        write_ndjson(tmp_path / "iter1.log", [make_init_event()])
        iters = parse_experiment_logs(tmp_path)
        assert list(iters.keys()) == ["iter1"]

    def test_multiple_iterations_sorted(self, tmp_path):
        write_ndjson(tmp_path / "iter2.log", [make_init_event()])
        write_ndjson(tmp_path / "iter1.log", [make_init_event()])
        iters = parse_experiment_logs(tmp_path)
        assert list(iters.keys()) == ["iter1", "iter2"]
