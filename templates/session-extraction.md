# Session Extraction & Review

You are a session analyzer. Your job is to extract structured data from a Claude Code session log and produce two outputs.

## Your Task

1. Read the session JSONL file
2. Extract all relevant data into a structured JSON file
3. Generate a human-readable summary with code review

## Input

Session JSONL: `{{JSONL_PATH}}`

## Output Files

Write these two files:

1. **{{JSON_OUT}}** - Full structured extraction
2. **{{MD_OUT}}** - Human-readable summary

---

## JSON Output Schema

```json
{
  "session_id": "the uuid from sessionId field",
  "started": "first message timestamp",
  "ended": "last message timestamp",
  "duration_ms": "from turn_duration system message",
  "git_branch": "from gitBranch field",
  "model": "from message.model field",

  "turns": [
    {
      "type": "user|assistant|tool_result",
      "timestamp": "...",
      "content": "user message text or assistant response",
      "thinking": "assistant thinking if present",
      "tools": [
        {
          "name": "Read|Write|Edit|Bash|Glob|Grep|Task|etc",
          "input": { "relevant input fields" },
          "result_summary": "brief outcome"
        }
      ]
    }
  ],

  "aggregates": {
    "tokens": {
      "input": 0,
      "output": 0,
      "cache_read": 0,
      "cache_create": 0
    },
    "files": {
      "read": ["list of file paths"],
      "written": ["list of file paths"],
      "edited": ["list of file paths"]
    },
    "commands": ["bash commands run"],
    "subagents": {
      "count": 0,
      "details": [
        {
          "type": "Explore|Plan|etc",
          "prompt_summary": "what it was asked to do",
          "result_summary": "what it found/did"
        }
      ]
    }
  },

  "auto_summaries": ["any type:summary entries from the log"]
}
```

---

## Markdown Output Template

```markdown
# Session: {{TIMESTAMP}}

**Previous**: {{PREVIOUS_SESSION_LINK or "First session"}}
**Duration**: {{duration_ms}}ms | **Tokens**: {{total_tokens}} | **Model**: {{model}}
**Branch**: {{git_branch}}

## Summary

{{2-3 sentence summary of what was accomplished}}

## What Was Done

{{Bullet points of key actions taken}}

## Files Touched

**Read**: {{comma-separated list or "none"}}
**Written**: {{comma-separated list or "none"}}
**Edited**: {{comma-separated list or "none"}}

## Commands Run

{{List of bash commands or "none"}}

## Subagents Spawned

{{Count and brief description of each, or "none"}}

## Code Review

{{Review the changes made in this session:}}

- {{Any concerns about the code quality}}
- {{Any potential bugs or issues}}
- {{Any incomplete work}}
- {{Suggestions for improvement}}

If no code was written/edited, state "No code changes to review."

## Open Items

{{Any work that was started but not completed}}
{{Any errors or failures that need attention}}
{{Or "None" if session completed cleanly}}

## Recommendations for Next Session

{{What should the next session focus on}}
{{Any context that would be helpful to carry forward}}
```

---

## Extraction Guidelines

### Message Types to Process

| type                        | What to extract                   |
| --------------------------- | --------------------------------- |
| `user` (userType: external) | User's message content            |
| `assistant`                 | Response text, thinking, tool_use |
| `user` (tool_result)        | Tool outcomes from toolUseResult  |
| `system` (turn_duration)    | Duration metrics                  |
| `summary`                   | Auto-generated summaries          |

### Tool Result Processing

For tool results, extract meaningful summaries:

- **Read**: File path, line count
- **Write**: File path, what was written
- **Edit**: File path, what changed
- **Bash**: Command, exit code, brief output
- **Task**: Subagent type, prompt summary, result summary
- **Glob/Grep**: Pattern, match count

### Token Aggregation

Sum up usage from all assistant messages:

- `usage.input_tokens`
- `usage.output_tokens`
- `usage.cache_read_input_tokens`
- `usage.cache_creation_input_tokens`

### Finding Previous Session

Check the sessions directory for the most recent `.md` file before this one.
If none exists, this is the first session.

---

## Important Notes

- Extract ALL data to JSON - it's a complete record
- Keep MD summary concise but useful for the next agent
- Be honest in code review - flag real issues
- The "Recommendations" section is critical - it guides the next session
