# Lessons

- When auditing sidecar handover behavior, treat handover activity as stronger than `Worker Done` pane text. Once `handover_active` is true, wait for `<END_TURN>` or the handover timeout.
