"""Tests for src/analyze/classify.py — event classification and phase boundaries."""

from src.analyze.classify import (
    classify_events, _classify_tool_call, _find_first_edit,
    _is_excluded_file, _matches_compiled, compute_phase_summary,
    NAV_BASH_RE, TASK_BASH_RE, BOILERPLATE_BASH_RE,
)


def _make_tool_event(tool_name, seq=0, file_path=None, command=None):
    event = {
        "type": "tool_call",
        "seq": seq,
        "tool_name": tool_name,
        "file_path": file_path,
        "command": command,
        "session_id": "sess-1",
        "tool_id": f"tool-{seq}",
        "arguments": {},
    }
    return event


def _make_token_event(seq=0, input_tokens=100, output_tokens=50, msg_id="msg-1"):
    return {
        "type": "token_usage",
        "seq": seq,
        "session_id": "sess-1",
        "message_id": msg_id,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0,
    }


class TestClassifyToolCall:
    def test_read_is_navigation(self):
        e = _make_tool_event("Read", file_path="/src/main.py")
        assert _classify_tool_call(e) == "navigation"

    def test_grep_is_navigation(self):
        e = _make_tool_event("Grep", file_path="/src")
        assert _classify_tool_call(e) == "navigation"

    def test_glob_is_navigation(self):
        e = _make_tool_event("Glob", file_path="**/*.py")
        assert _classify_tool_call(e) == "navigation"

    def test_webfetch_is_navigation(self):
        e = _make_tool_event("WebFetch")
        assert _classify_tool_call(e) == "navigation"

    def test_task_is_navigation(self):
        e = _make_tool_event("Task")
        assert _classify_tool_call(e) == "navigation"

    def test_task_output_is_navigation(self):
        e = _make_tool_event("TaskOutput")
        assert _classify_tool_call(e) == "navigation"

    def test_edit_is_task_work(self):
        e = _make_tool_event("Edit", file_path="/src/main.py")
        assert _classify_tool_call(e) == "task_work"

    def test_write_is_task_work(self):
        e = _make_tool_event("Write", file_path="/src/new.py")
        assert _classify_tool_call(e) == "task_work"

    def test_todo_write_is_boilerplate(self):
        e = _make_tool_event("TodoWrite")
        assert _classify_tool_call(e) == "boilerplate"

    def test_kill_shell_is_boilerplate(self):
        e = _make_tool_event("KillShell")
        assert _classify_tool_call(e) == "boilerplate"

    def test_linear_mcp_is_boilerplate(self):
        e = _make_tool_event("mcp__linear-server__get_issue")
        assert _classify_tool_call(e) == "boilerplate"

    def test_context7_is_navigation(self):
        e = _make_tool_event("mcp__context7__query-docs")
        assert _classify_tool_call(e) == "navigation"

    def test_read_symbol_is_fmm_navigation(self):
        e = _make_tool_event("mcp__mcp-files__read_symbol", file_path="/src/main.ts")
        assert _classify_tool_call(e) == "fmm_navigation"

    def test_read_fmm_file_is_fmm_navigation(self):
        e = _make_tool_event("Read", file_path="/src/main.ts.fmm")
        assert _classify_tool_call(e) == "fmm_navigation"

    def test_bash_fmm_grep_is_fmm_navigation(self):
        e = _make_tool_event("Bash", command="grep fmm search results")
        assert _classify_tool_call(e) == "fmm_navigation"

    def test_skill_check_directives_is_boilerplate(self):
        e = _make_tool_event("Skill", command="nancy-check-directives")
        assert _classify_tool_call(e) == "boilerplate"

    def test_skill_nancy_is_boilerplate(self):
        e = _make_tool_event("Skill", command="nancy:orchestrator:status")
        assert _classify_tool_call(e) == "boilerplate"

    def test_skill_other_is_other(self):
        e = _make_tool_event("Skill", command="commit")
        assert _classify_tool_call(e) == "other"

    def test_bash_git_log_is_navigation(self):
        e = _make_tool_event("Bash", command="git log --oneline -5")
        assert _classify_tool_call(e) == "navigation"

    def test_bash_git_commit_is_task_work(self):
        e = _make_tool_event("Bash", command="git commit -m 'fix'")
        assert _classify_tool_call(e) == "task_work"

    def test_bash_pytest_is_task_work(self):
        e = _make_tool_event("Bash", command="pytest tests/")
        assert _classify_tool_call(e) == "task_work"

    def test_bash_nancy_inbox_is_boilerplate(self):
        e = _make_tool_event("Bash", command="nancy inbox")
        assert _classify_tool_call(e) == "boilerplate"

    def test_bash_ls_is_navigation(self):
        e = _make_tool_event("Bash", command="ls -la /src")
        assert _classify_tool_call(e) == "navigation"

    def test_bash_unknown_defaults_to_navigation(self):
        e = _make_tool_event("Bash", command="some-custom-script")
        assert _classify_tool_call(e) == "navigation"

    def test_unknown_tool_is_other(self):
        e = _make_tool_event("SomeNewTool")
        assert _classify_tool_call(e) == "other"


class TestIsExcludedFile:
    def test_issues_md(self):
        assert _is_excluded_file("/project/ISSUES.md")

    def test_complete(self):
        assert _is_excluded_file("/project/.nancy/tasks/ALP-487/COMPLETE")

    def test_nancy_dir(self):
        assert _is_excluded_file("/project/.nancy/config.yaml")

    def test_config_json(self):
        assert _is_excluded_file("/project/config.json")

    def test_source_file_not_excluded(self):
        assert not _is_excluded_file("/src/main.py")

    def test_empty_string_not_excluded(self):
        assert not _is_excluded_file("")


class TestMatchesCompiled:
    def test_nav_bash_ls(self):
        assert _matches_compiled("ls /src", NAV_BASH_RE)

    def test_nav_bash_git_status(self):
        assert _matches_compiled("git status", NAV_BASH_RE)

    def test_task_bash_npm_test(self):
        assert _matches_compiled("npm test", TASK_BASH_RE)

    def test_boilerplate_nancy_inbox(self):
        assert _matches_compiled("nancy inbox", BOILERPLATE_BASH_RE)

    def test_no_match(self):
        assert not _matches_compiled("curl https://example.com", NAV_BASH_RE)


class TestFindFirstEdit:
    def test_no_edits(self):
        events = [
            _make_tool_event("Read", seq=0, file_path="/a.py"),
            _make_tool_event("Grep", seq=1, file_path="/src"),
        ]
        assert _find_first_edit(events) is None

    def test_edit_to_source_file(self):
        events = [
            _make_tool_event("Read", seq=0, file_path="/a.py"),
            _make_tool_event("Edit", seq=1, file_path="/src/main.py"),
        ]
        assert _find_first_edit(events) == 1

    def test_edit_to_excluded_file_skipped(self):
        events = [
            _make_tool_event("Edit", seq=0, file_path="/project/ISSUES.md"),
            _make_tool_event("Edit", seq=1, file_path="/src/main.py"),
        ]
        assert _find_first_edit(events) == 1

    def test_write_counts_as_edit(self):
        events = [
            _make_tool_event("Write", seq=0, file_path="/src/new_file.py"),
        ]
        assert _find_first_edit(events) == 0

    def test_nancy_dir_excluded(self):
        events = [
            _make_tool_event("Edit", seq=0, file_path="/project/.nancy/config.yaml"),
            _make_tool_event("Edit", seq=1, file_path="/src/app.ts"),
        ]
        assert _find_first_edit(events) == 1


class TestClassifyEvents:
    def test_phases_assigned(self):
        events = [
            _make_tool_event("Read", seq=0, file_path="/a.py"),
            _make_tool_event("Edit", seq=1, file_path="/a.py"),
            _make_tool_event("Bash", seq=2, command="npm test"),
        ]
        classified, first_edit = classify_events(events)
        assert first_edit == 1
        assert classified[0]["phase"] == "nav"
        assert classified[1]["phase"] == "work"
        assert classified[2]["phase"] == "work"

    def test_no_edits_all_nav(self):
        events = [
            _make_tool_event("Read", seq=0, file_path="/a.py"),
            _make_tool_event("Grep", seq=1, file_path="/src"),
        ]
        classified, first_edit = classify_events(events)
        assert first_edit is None
        assert all(e["phase"] == "nav" for e in classified)

    def test_token_event_gets_category(self):
        events = [_make_token_event(seq=0)]
        classified, _ = classify_events(events)
        assert classified[0]["category"] == "token_usage"

    def test_init_event_is_boilerplate(self):
        events = [{"type": "init", "seq": 0, "session_id": "s"}]
        classified, _ = classify_events(events)
        assert classified[0]["category"] == "boilerplate"


class TestComputePhaseSummary:
    def test_basic_summary(self):
        events = [
            {**_make_tool_event("Read", seq=0, file_path="/a.py"), "category": "navigation", "phase": "nav"},
            {**_make_tool_event("Grep", seq=1, file_path="/src"), "category": "navigation", "phase": "nav"},
            {**_make_token_event(seq=2, input_tokens=500, output_tokens=100, msg_id="m1"), "category": "token_usage", "phase": "nav"},
            {**_make_tool_event("Edit", seq=3, file_path="/a.py"), "category": "task_work", "phase": "work"},
            {**_make_token_event(seq=4, input_tokens=200, output_tokens=80, msg_id="m2"), "category": "token_usage", "phase": "work"},
        ]
        summary = compute_phase_summary(events, first_edit_seq=3)

        assert summary["nav_phase"]["reads"] == 1
        assert summary["nav_phase"]["greps"] == 1
        assert summary["nav_phase"]["tool_call_count"] == 2
        assert summary["nav_phase"]["token_total"] == 600  # 500 + 100
        assert summary["work_phase"]["tool_call_count"] == 1
        assert summary["work_phase"]["token_total"] == 280  # 200 + 80
        assert summary["totals"]["token_total"] == 880
        assert summary["has_edits"] is True
        assert summary["first_edit_seq"] == 3

    def test_token_dedup_by_message_id(self):
        events = [
            {**_make_token_event(seq=0, input_tokens=100, output_tokens=50, msg_id="msg-dup"),
             "category": "token_usage", "phase": "nav", "source": "stream_message_start"},
            {**_make_token_event(seq=1, input_tokens=100, output_tokens=50, msg_id="msg-dup"),
             "category": "token_usage", "phase": "nav"},
        ]
        summary = compute_phase_summary(events, first_edit_seq=None)
        # Should only count once
        assert summary["totals"]["token_total"] == 150

    def test_fmm_lookups_counted(self):
        events = [
            {**_make_tool_event("mcp__mcp-files__read_symbol", seq=0, file_path="/a.ts"),
             "category": "fmm_navigation", "phase": "nav"},
            {**_make_tool_event("Read", seq=1, file_path="/a.ts.fmm"),
             "category": "fmm_navigation", "phase": "nav"},
            {**_make_tool_event("Read", seq=2, file_path="/b.py"),
             "category": "navigation", "phase": "nav"},
        ]
        summary = compute_phase_summary(events, first_edit_seq=None)
        assert summary["nav_phase"]["fmm_lookups"] == 2
        assert summary["nav_phase"]["raw_nav_lookups"] == 1

    def test_no_events(self):
        summary = compute_phase_summary([], first_edit_seq=None)
        assert summary["nav_phase"]["tool_call_count"] == 0
        assert summary["totals"]["token_total"] == 0
        assert summary["has_edits"] is False

    def test_unique_files_tracked(self):
        events = [
            {**_make_tool_event("Read", seq=0, file_path="/a.py"), "category": "navigation", "phase": "nav"},
            {**_make_tool_event("Read", seq=1, file_path="/a.py"), "category": "navigation", "phase": "nav"},
            {**_make_tool_event("Read", seq=2, file_path="/b.py"), "category": "navigation", "phase": "nav"},
        ]
        summary = compute_phase_summary(events, first_edit_seq=None)
        assert summary["nav_phase"]["unique_file_count"] == 2
        assert sorted(summary["nav_phase"]["unique_files"]) == ["/a.py", "/b.py"]
