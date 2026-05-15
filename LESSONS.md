# Lessons

- When auditing sidecar handover behavior, treat handover activity as stronger than `Worker Done` pane text. Once `handover_active` is true, wait for `<END_TURN>` or the handover timeout.
- When a selected Nancy issue points at a file in a different repo, name the repo boundary explicitly before calling anything dirty or deciding commit scope.
- During ALP-2420, Stuart is on hand to resolve blockers. Do not bail or exit early for human direction ambiguity; ask Stuart and continue once resolved.
- When ALP-2420 selector work approaches the 700 LOC guardrail, decompose along module boundaries instead of shaving lines or weakening behavior to fit.
