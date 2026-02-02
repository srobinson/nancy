"""Tests for src/analyze/compare.py — aggregation, formatting, JSON output."""

import json

from src.analyze.compare import (
    analyze_condition, _aggregate_iterations, format_comparison_table,
    format_json_output, _summarize_for_json,
)
from tests.conftest import (
    write_ndjson, make_init_event, make_assistant_event, make_tool_use_block,
    make_user_event,
)


def _make_phase_summary(nav_reads=0, nav_greps=0, nav_unique_files=None,
                         nav_token_total=0, work_token_total=0,
                         fmm_lookups=0, raw_nav_lookups=0,
                         first_edit_seq=None):
    """Build a minimal phase summary for testing aggregation."""
    has_edits = first_edit_seq is not None
    nav_files = nav_unique_files or []
    return {
        "nav_phase": {
            "tool_counts": {"Read": nav_reads, "Grep": nav_greps},
            "tool_call_count": nav_reads + nav_greps,
            "tokens": {"input": nav_token_total, "output": 0, "cache_create": 0, "cache_read": 0},
            "token_total": nav_token_total,
            "unique_files": nav_files,
            "unique_file_count": len(nav_files),
            "reads": nav_reads,
            "greps": nav_greps,
            "fmm_lookups": fmm_lookups,
            "raw_nav_lookups": raw_nav_lookups,
        },
        "work_phase": {
            "tool_counts": {},
            "tool_call_count": 0,
            "tokens": {"input": work_token_total, "output": 0, "cache_create": 0, "cache_read": 0},
            "token_total": work_token_total,
            "unique_files": [],
            "unique_file_count": 0,
        },
        "totals": {
            "tokens": {"input": nav_token_total + work_token_total, "output": 0, "cache_create": 0, "cache_read": 0},
            "token_total": nav_token_total + work_token_total,
            "tool_calls": nav_reads + nav_greps,
        },
        "first_edit_seq": first_edit_seq,
        "has_edits": has_edits,
    }


class TestAggregateIterations:
    def test_single_iteration(self):
        per_iter = {
            "iter1": _make_phase_summary(
                nav_reads=5, nav_greps=3,
                nav_unique_files=["/a.py", "/b.py"],
                nav_token_total=1000, work_token_total=500,
                fmm_lookups=2, raw_nav_lookups=6,
                first_edit_seq=10,
            ),
        }
        agg = _aggregate_iterations(per_iter)
        assert agg["iteration_count"] == 1
        assert agg["nav_reads"] == 5
        assert agg["nav_greps"] == 3
        assert agg["nav_unique_file_count"] == 2
        assert agg["nav_tokens"] == 1000
        assert agg["total_tokens"] == 1500
        assert agg["fmm_lookups"] == 2
        assert agg["raw_nav_lookups"] == 6
        assert agg["has_edits"] is True
        assert agg["first_edit_iteration"] == "iter1"
        assert agg["nav_pct"] == 67  # 1000/1500 ~ 67%
        assert agg["sidecar_ratio"] == "2/8"

    def test_multiple_iterations(self):
        per_iter = {
            "iter1": _make_phase_summary(
                nav_reads=3, nav_unique_files=["/a.py"],
                nav_token_total=500, work_token_total=200,
            ),
            "iter2": _make_phase_summary(
                nav_reads=2, nav_unique_files=["/a.py", "/c.py"],
                nav_token_total=300, work_token_total=100,
                first_edit_seq=5,
            ),
        }
        agg = _aggregate_iterations(per_iter)
        assert agg["iteration_count"] == 2
        assert agg["nav_reads"] == 5
        # Unique files across iterations (set union): /a.py, /c.py
        assert agg["nav_unique_file_count"] == 2
        assert agg["nav_tokens"] == 800
        assert agg["total_tokens"] == 1100

    def test_no_edits(self):
        per_iter = {
            "iter1": _make_phase_summary(nav_reads=2, nav_token_total=200),
        }
        agg = _aggregate_iterations(per_iter)
        assert agg["has_edits"] is False
        assert agg["first_edit_iteration"] is None
        assert agg["first_edit_pct"] is None

    def test_no_nav_lookups(self):
        per_iter = {
            "iter1": _make_phase_summary(nav_token_total=100),
        }
        agg = _aggregate_iterations(per_iter)
        assert agg["sidecar_ratio"] == "n/a"

    def test_zero_tokens(self):
        per_iter = {
            "iter1": _make_phase_summary(),
        }
        agg = _aggregate_iterations(per_iter)
        assert agg["nav_pct"] == 0


class TestFormatComparisonTable:
    def test_table_contains_headers(self):
        ctrl = _aggregate_iterations({"i1": _make_phase_summary(nav_reads=1, nav_token_total=100, work_token_total=50)})
        treat = _aggregate_iterations({"i1": _make_phase_summary(nav_reads=2, nav_token_total=200, work_token_total=80, fmm_lookups=3, raw_nav_lookups=1)})
        table = format_comparison_table(ctrl, treat)
        assert "Control (no fmm)" in table
        assert "Treatment (fmm)" in table

    def test_table_has_all_rows(self):
        ctrl = _aggregate_iterations({"i1": _make_phase_summary(nav_reads=1, nav_token_total=100, work_token_total=50)})
        treat = _aggregate_iterations({"i1": _make_phase_summary(nav_reads=2, nav_token_total=200, work_token_total=80)})
        table = format_comparison_table(ctrl, treat)
        expected_labels = [
            "Reads before first edit",
            "Greps before first edit",
            "Unique files discovered",
            "Navigation tokens",
            "Navigation % of total",
            "Time to first edit",
            "Sidecar lookups",
            "Task complete",
            "Total iterations",
            "Total tokens",
        ]
        for label in expected_labels:
            assert label in table

    def test_custom_labels(self):
        ctrl = _aggregate_iterations({"i1": _make_phase_summary()})
        treat = _aggregate_iterations({"i1": _make_phase_summary()})
        table = format_comparison_table(ctrl, treat, "Baseline", "Experiment")
        assert "Baseline" in table
        assert "Experiment" in table

    def test_large_token_formatting(self):
        ctrl = _aggregate_iterations({"i1": _make_phase_summary(nav_token_total=50000, work_token_total=10000)})
        treat = _aggregate_iterations({"i1": _make_phase_summary(nav_token_total=30000, work_token_total=5000)})
        table = format_comparison_table(ctrl, treat)
        assert "~50,000" in table or "~60,000" in table


class TestFormatJsonOutput:
    def test_json_serializable(self):
        ctrl_iter = {"i1": _make_phase_summary(nav_reads=1, nav_unique_files=["/a.py"])}
        treat_iter = {"i1": _make_phase_summary(nav_reads=2, nav_unique_files=["/b.py"])}
        ctrl_agg = _aggregate_iterations(ctrl_iter)
        treat_agg = _aggregate_iterations(treat_iter)
        output = format_json_output(ctrl_iter, ctrl_agg, treat_iter, treat_agg)
        # Must be JSON-serializable
        json_str = json.dumps(output)
        parsed = json.loads(json_str)
        assert "control" in parsed
        assert "treatment" in parsed
        assert "iterations" in parsed["control"]
        assert "aggregate" in parsed["control"]

    def test_unique_files_sorted(self):
        summary = _make_phase_summary(nav_unique_files=["/z.py", "/a.py"])
        result = _summarize_for_json(summary)
        assert result["nav_phase"]["unique_files"] == ["/a.py", "/z.py"]


class TestAnalyzeCondition:
    def test_end_to_end(self, tmp_path):
        """Integration test: write logs, analyze, verify structure."""
        # Create a minimal log with a Read then an Edit
        events = [
            make_init_event(),
            make_user_event(),
            make_assistant_event(
                [make_tool_use_block("Read", {"file_path": "/src/main.py"}, tool_id="t1")],
                msg_id="m1", input_tokens=500, output_tokens=100,
            ),
            make_assistant_event(
                [make_tool_use_block("Edit", {"file_path": "/src/main.py"}, tool_id="t2")],
                msg_id="m2", input_tokens=400, output_tokens=200,
            ),
        ]
        write_ndjson(tmp_path / "iter1.log", events)

        per_iter, aggregate = analyze_condition(tmp_path)
        assert "iter1" in per_iter
        assert aggregate["iteration_count"] == 1
        assert aggregate["has_edits"] is True
        assert aggregate["nav_reads"] >= 1
        assert aggregate["total_tokens"] > 0
