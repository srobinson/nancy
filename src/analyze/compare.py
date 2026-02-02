#!/usr/bin/env python3
"""Generate comparison tables from two analyzed experiment conditions.

Takes control and treatment log directories, parses + classifies all iterations,
and outputs a comparison table matching the EXPERIMENT_HARNESS.md format.
"""

import json
import sys
from pathlib import Path

from .parse_logs import parse_experiment_logs
from .classify import classify_events, compute_phase_summary


def analyze_condition(log_dir):
    """Analyze all iterations in a condition's log directory.

    Returns:
      - per_iteration: dict of {iter_name: phase_summary}
      - aggregate: combined summary across all iterations
    """
    iterations = parse_experiment_logs(log_dir)
    per_iteration = {}

    for name, events in iterations.items():
        classified, first_edit_seq = classify_events(events)
        summary = compute_phase_summary(classified, first_edit_seq)
        summary["iteration_name"] = name
        per_iteration[name] = summary

    aggregate = _aggregate_iterations(per_iteration)
    return per_iteration, aggregate


def _aggregate_iterations(per_iteration):
    """Combine summaries across iterations."""
    agg = {
        "iteration_count": len(per_iteration),
        "nav_reads": 0,
        "nav_greps": 0,
        "nav_unique_files": set(),
        "nav_tokens": 0,
        "total_tokens": 0,
        "fmm_lookups": 0,
        "raw_nav_lookups": 0,
        "has_edits": False,
        "first_edit_iteration": None,
        "first_edit_pct": None,
    }

    total_events_before_first_edit = 0
    total_events_overall = 0

    for name, summary in sorted(per_iteration.items()):
        nav = summary["nav_phase"]
        agg["nav_reads"] += nav["reads"]
        agg["nav_greps"] += nav["greps"]
        agg["nav_unique_files"].update(nav["unique_files"])
        agg["nav_tokens"] += nav["token_total"]
        agg["total_tokens"] += summary["totals"]["token_total"]
        agg["fmm_lookups"] += nav["fmm_lookups"]
        agg["raw_nav_lookups"] += nav["raw_nav_lookups"]

        if summary["has_edits"]:
            agg["has_edits"] = True
            if agg["first_edit_iteration"] is None:
                agg["first_edit_iteration"] = name
                # Approximate "position" as nav tokens / total tokens for that iter
                iter_total = summary["totals"]["token_total"]
                if iter_total > 0:
                    agg["first_edit_pct"] = round(
                        nav["token_total"] / iter_total * 100
                    )

    agg["nav_unique_file_count"] = len(agg["nav_unique_files"])
    agg["nav_unique_files"] = sorted(agg["nav_unique_files"])

    if agg["total_tokens"] > 0:
        agg["nav_pct"] = round(agg["nav_tokens"] / agg["total_tokens"] * 100)
    else:
        agg["nav_pct"] = 0

    total_nav = agg["fmm_lookups"] + agg["raw_nav_lookups"]
    if total_nav > 0:
        agg["sidecar_ratio"] = f"{agg['fmm_lookups']}/{total_nav}"
    else:
        agg["sidecar_ratio"] = "n/a"

    return agg


def format_comparison_table(control_agg, treatment_agg, control_label="Control (no fmm)", treatment_label="Treatment (fmm)"):
    """Format the comparison table as a string."""

    def _fmt_tokens(n):
        if n >= 1000:
            return f"~{n:,}"
        return str(n)

    def _first_edit_str(agg):
        if agg["first_edit_iteration"]:
            iter_short = agg["first_edit_iteration"].split("-")[-1]  # e.g. "iter1"
            return f"{iter_short} @ {agg['first_edit_pct']}%"
        return "no edits"

    def _sidecar_str(agg, is_treatment):
        if not is_treatment:
            return "n/a"
        return agg["sidecar_ratio"]

    def _task_complete(agg):
        return "yes" if agg["has_edits"] else "no edits"

    rows = [
        ("Reads before first edit", str(control_agg["nav_reads"]), str(treatment_agg["nav_reads"])),
        ("Greps before first edit", str(control_agg["nav_greps"]), str(treatment_agg["nav_greps"])),
        ("Unique files discovered", str(control_agg["nav_unique_file_count"]), str(treatment_agg["nav_unique_file_count"])),
        ("Navigation tokens", _fmt_tokens(control_agg["nav_tokens"]), _fmt_tokens(treatment_agg["nav_tokens"])),
        ("Navigation % of total", f"{control_agg['nav_pct']}%", f"{treatment_agg['nav_pct']}%"),
        ("Time to first edit", _first_edit_str(control_agg), _first_edit_str(treatment_agg)),
        ("Sidecar lookups", _sidecar_str(control_agg, False), _sidecar_str(treatment_agg, True)),
        ("Task complete", _task_complete(control_agg), _task_complete(treatment_agg)),
        ("Total iterations", str(control_agg["iteration_count"]), str(treatment_agg["iteration_count"])),
        ("Total tokens", _fmt_tokens(control_agg["total_tokens"]), _fmt_tokens(treatment_agg["total_tokens"])),
    ]

    label_w = max(len(r[0]) for r in rows) + 2
    c_w = max(len(control_label), max(len(r[1]) for r in rows)) + 2
    t_w = max(len(treatment_label), max(len(r[2]) for r in rows)) + 2

    lines = []
    header = f"{'':>{label_w}}  {control_label:<{c_w}}  {treatment_label:<{t_w}}"
    lines.append(header)
    lines.append(f"{'':>{label_w}}  {'─' * c_w}  {'─' * t_w}")

    for label, c_val, t_val in rows:
        lines.append(f"{label + ':':<{label_w}}  {c_val:<{c_w}}  {t_val:<{t_w}}")

    return "\n".join(lines)


def format_json_output(control_per_iter, control_agg, treatment_per_iter, treatment_agg):
    """Format full results as JSON-serializable dict."""
    def _clean_agg(agg):
        a = dict(agg)
        a["nav_unique_files"] = sorted(a.get("nav_unique_files", []))
        return a

    return {
        "control": {
            "iterations": {k: _summarize_for_json(v) for k, v in control_per_iter.items()},
            "aggregate": _clean_agg(control_agg),
        },
        "treatment": {
            "iterations": {k: _summarize_for_json(v) for k, v in treatment_per_iter.items()},
            "aggregate": _clean_agg(treatment_agg),
        },
    }


def _summarize_for_json(summary):
    """Convert a phase summary to JSON-serializable form."""
    s = dict(summary)
    s["nav_phase"] = dict(s["nav_phase"])
    s["nav_phase"]["unique_files"] = sorted(s["nav_phase"].get("unique_files", []))
    s["work_phase"] = dict(s["work_phase"])
    s["work_phase"]["unique_files"] = sorted(s["work_phase"].get("unique_files", []))
    s["totals"] = dict(s["totals"])
    return s


def main():
    if len(sys.argv) < 3:
        print("Usage: compare.py <control_log_dir> <treatment_log_dir> [--json]", file=sys.stderr)
        sys.exit(1)

    control_dir = Path(sys.argv[1])
    treatment_dir = Path(sys.argv[2])
    as_json = "--json" in sys.argv

    if not control_dir.is_dir():
        print(f"Error: {control_dir} not found", file=sys.stderr)
        sys.exit(1)
    if not treatment_dir.is_dir():
        print(f"Error: {treatment_dir} not found", file=sys.stderr)
        sys.exit(1)

    control_per_iter, control_agg = analyze_condition(control_dir)
    treatment_per_iter, treatment_agg = analyze_condition(treatment_dir)

    if as_json:
        output = format_json_output(control_per_iter, control_agg, treatment_per_iter, treatment_agg)
        json.dump(output, sys.stdout, indent=2)
        print()
    else:
        table = format_comparison_table(control_agg, treatment_agg)
        print(table)
        print()

        # Per-iteration detail
        print("\n--- Per-iteration detail ---\n")
        for label, per_iter in [("CONTROL", control_per_iter), ("TREATMENT", treatment_per_iter)]:
            print(f"  {label}:")
            for name, summary in sorted(per_iter.items()):
                nav = summary["nav_phase"]
                totals = summary["totals"]
                edit_str = f"first edit @ seq {summary['first_edit_seq']}" if summary["has_edits"] else "no edits"
                print(f"    {name}: {nav['tool_call_count']} nav calls, "
                      f"{nav['token_total']:,} nav tokens, "
                      f"{totals['token_total']:,} total tokens, "
                      f"{edit_str}")
            print()


if __name__ == "__main__":
    main()
