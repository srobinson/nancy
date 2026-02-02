---
name: check-directives
description: Check for orchestrator messages.
---

# Check Directives

## Check Inbox

```bash
nancy inbox
```

## Process Each Message

For each message file:

1. **Read** the message
2. **Act** based on type:
   - `directive` - Follow the specific instruction
   - `guidance` - Adjust your approach accordingly
   - `stop` - End task immediately, do not continue
3. **Archive** immediately after acting:

   ```bash
   nancy archive <filename>
   ```

If output shows ANY pending directives:

- Process and archive them first
- Do NOT mark complete until inbox is empty
