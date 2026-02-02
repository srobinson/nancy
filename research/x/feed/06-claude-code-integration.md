# Claude Code Integration for X/Twitter Engagement Assistant

## Executive Summary

This document explores integration patterns for building a Twitter/X engagement assistant that leverages Claude Code as the AI brain rather than building a standalone app with external LLM APIs. The key finding: **MCP Server integration is the most straightforward approach** for a local personal tool, providing seamless access to feed data within Claude Code conversations.

**Recommended Architecture**: Build an MCP server exposing Twitter feed tools that Claude Code connects to via stdio. This gives you:
- Natural language interaction with your feed directly in the terminal
- Claude's full reasoning capabilities for content analysis and drafting
- Integration with existing Claude Code skills and workflows
- Zero additional LLM API costs (uses your existing Claude Code subscription)

---

## Table of Contents

1. [Integration Approaches Overview](#integration-approaches-overview)
2. [Approach 1: MCP Server Integration](#approach-1-mcp-server-integration)
3. [Approach 2: Claude Code as AI Brain](#approach-2-claude-code-as-ai-brain)
4. [Approach 3: Hooks Integration](#approach-3-hooks-integration)
5. [Approach 4: Custom Skills](#approach-4-custom-skills)
6. [Approach 5: Context Bridging](#approach-5-context-bridging)
7. [Architecture Comparison](#architecture-comparison)
8. [Recommendation](#recommendation)

---

## Integration Approaches Overview

| Approach | Complexity | Flexibility | Claude Code Integration | Best For |
|----------|------------|-------------|------------------------|----------|
| **MCP Server** | Medium | High | Native | Full workflow integration |
| **AI Brain Piping** | High | Medium | Manual | Existing app enhancement |
| **Hooks** | Low | Low | Native | Event-driven automation |
| **Custom Skills** | Low | Medium | Native | Command-driven workflows |
| **Context Bridging** | Low | High | Manual | Ad-hoc analysis |

---

## Approach 1: MCP Server Integration

### Concept

Build a local MCP server that exposes your Twitter feed monitoring and engagement tools. Claude Code connects to this server via stdio, making feed data and actions available as tools within any conversation.

```
+------------------------------------------------------------------+
|                      CLAUDE CODE (Terminal)                       |
|  "What's trending in my feed?" / "Draft a reply to this thread"  |
+------------------------------------------------------------------+
                              |
                         MCP Protocol
                              |
                              v
+------------------------------------------------------------------+
|                     X-FEED MCP SERVER (stdio)                     |
|                    Python / Node.js / Go                          |
+------------------------------------------------------------------+
|  TOOLS:                                                           |
|  - get_feed(count, category)     - get_thread(tweet_id)          |
|  - get_trending()                - draft_reply(tweet_id, style)  |
|  - get_vip_activity()            - draft_post(topic, style)      |
|  - search_feed(query)            - save_draft(content)           |
|  - get_saved_items()             - analyze_tweet(tweet_id)       |
+------------------------------------------------------------------+
                              |
                              v
+------------------------------------------------------------------+
|                         DATA LAYER                                |
|  +-------------------+  +-------------------+                     |
|  | SQLite Database   |  | TwitterAPI.io     |                     |
|  | (cached tweets)   |  | (live API)        |                     |
|  +-------------------+  +-------------------+                     |
+------------------------------------------------------------------+
```

### MCP Server Implementation (Python/FastMCP)

```python
# x_feed_server.py
from mcp.server.fastmcp import FastMCP
import sqlite3
from datetime import datetime
import json

mcp = FastMCP("X-Feed Assistant")

# Database connection
DB_PATH = "~/.x-feed/feed.db"

@mcp.tool()
def get_feed(
    count: int = 20,
    category: str = "all",
    hours: int = 24
) -> str:
    """
    Get recent tweets from your followed accounts.

    Args:
        count: Number of tweets to return (max 50)
        category: Filter by category (all, tech, ai, crypto, vip, etc.)
        hours: Only show tweets from last N hours

    Returns:
        JSON array of tweets with author, text, engagement metrics, and ID
    """
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    query = """
        SELECT t.id, t.text, t.likes, t.retweets, t.created_at,
               a.handle, a.display_name, a.priority_tier
        FROM tweets t
        JOIN followed_accounts a ON t.author_id = a.id
        WHERE t.created_at > datetime('now', '-{} hours')
    """.format(hours)

    if category != "all":
        query += f" AND a.categories LIKE '%{category}%'"

    query += " ORDER BY t.engagement_score DESC LIMIT ?"

    cursor.execute(query, (min(count, 50),))
    tweets = cursor.fetchall()
    conn.close()

    return json.dumps([{
        "id": t[0],
        "text": t[1],
        "likes": t[2],
        "retweets": t[3],
        "created_at": t[4],
        "author": f"@{t[5]}",
        "author_name": t[6],
        "priority": t[7]
    } for t in tweets], indent=2)


@mcp.tool()
def get_thread(tweet_id: str) -> str:
    """
    Get full thread context for a tweet.

    Args:
        tweet_id: The ID of any tweet in the thread

    Returns:
        Full thread with all tweets in chronological order
    """
    # Implementation fetches thread via conversation_id
    pass


@mcp.tool()
def get_vip_activity(hours: int = 4) -> str:
    """
    Get recent activity from your VIP accounts (people you care most about).

    Args:
        hours: Look back window in hours

    Returns:
        Recent tweets, replies, and threads from VIP accounts
    """
    pass


@mcp.tool()
def draft_reply(
    tweet_id: str,
    tone: str = "default",
    angle: str = ""
) -> str:
    """
    Draft a reply to a specific tweet. Does NOT post - returns draft for review.

    Args:
        tweet_id: ID of tweet to reply to
        tone: Voice tone (witty, thoughtful, supportive, contrarian, default)
        angle: Optional specific angle or point to make

    Returns:
        3 draft reply options with character counts
    """
    # Get tweet context
    # Use voice profile
    # Generate options
    pass


@mcp.tool()
def draft_post(
    topic: str,
    style: str = "thread",
    max_tweets: int = 1
) -> str:
    """
    Draft an original post or thread. Does NOT post - returns draft for review.

    Args:
        topic: What to post about
        style: Format (single, thread, poll_question)
        max_tweets: For threads, maximum number of tweets

    Returns:
        Draft post(s) with character counts and engagement predictions
    """
    pass


@mcp.tool()
def analyze_tweet(tweet_id: str) -> str:
    """
    Deep analysis of a tweet for engagement opportunity assessment.

    Args:
        tweet_id: Tweet to analyze

    Returns:
        Analysis including topic, sentiment, author context, reply opportunities,
        thread quality, and engagement recommendation
    """
    pass


@mcp.tool()
def search_feed(query: str, days: int = 7) -> str:
    """
    Search your cached feed for specific topics or keywords.

    Args:
        query: Search term (supports FTS5 syntax)
        days: How far back to search

    Returns:
        Matching tweets ranked by relevance
    """
    pass


@mcp.tool()
def get_trending(scope: str = "following") -> str:
    """
    Get trending topics within your feed or globally.

    Args:
        scope: "following" for your network, "global" for X-wide trends

    Returns:
        Top trending topics with example tweets
    """
    pass


@mcp.tool()
def save_for_later(tweet_id: str, reason: str = "") -> str:
    """
    Save a tweet to your engagement queue for later.

    Args:
        tweet_id: Tweet to save
        reason: Why you're saving it (optional note)

    Returns:
        Confirmation with current queue size
    """
    pass


@mcp.tool()
def get_saved_items(status: str = "pending") -> str:
    """
    Get your saved items queue.

    Args:
        status: Filter by status (pending, drafted, posted, archived)

    Returns:
        Saved items with their status and any drafts
    """
    pass


# Run with stdio transport for Claude Code
if __name__ == "__main__":
    mcp.run(transport="stdio")
```

### MCP Configuration for Claude Code

Add to `~/.claude/settings.json` or project `.mcp.json`:

```json
{
  "x-feed": {
    "command": "python",
    "args": ["-m", "x_feed_server"],
    "env": {
      "PYTHONUNBUFFERED": "1",
      "X_FEED_DB": "${HOME}/.x-feed/feed.db",
      "TWITTER_API_KEY": "${TWITTER_API_KEY}"
    }
  }
}
```

### Pros

- **Native integration**: Tools appear in Claude Code like any other tool
- **Conversational**: "What did @pmarca tweet about today?" just works
- **Full Claude reasoning**: Complex analysis without token limits of API calls
- **Context preservation**: Claude remembers previous feed discussions in session
- **Composable**: Combine with other MCP tools (file system, Git, etc.)
- **No additional LLM costs**: Uses existing Claude Code subscription

### Cons

- **Requires MCP server implementation**: Need to build and maintain the server
- **No standalone UI**: Must use Claude Code terminal
- **Offline dependency**: MCP server must be running
- **Learning curve**: Users need to know available tools

---

## Approach 2: Claude Code as AI Brain

### Concept

Instead of the app calling Groq/OpenAI APIs, pipe content TO Claude Code for processing. The app handles data fetching and UI, Claude Code handles AI analysis.

```
+------------------------------------------------------------------+
|                    X-FEED APP (Web UI / TUI)                      |
|                    localhost:8000 or terminal                     |
+------------------------------------------------------------------+
           |                                    |
           | HTTP/WebSocket                     | Subprocess pipe
           v                                    v
+-------------------+                 +------------------------+
| Feed Display      |                 | Claude Code Process    |
| User Interactions |<--------------->| (via CLI or API)       |
| Draft Management  |   JSON/Text     | AI Analysis & Drafting |
+-------------------+                 +------------------------+
           |
           v
+------------------------------------------------------------------+
|                      EXTERNAL SERVICES                            |
|  +-------------------+  +-------------------+                     |
|  | Twitter API       |  | SQLite Database   |                     |
|  +-------------------+  +-------------------+                     |
+------------------------------------------------------------------+
```

### Implementation Pattern

```python
# app/ai_service.py
import subprocess
import json

class ClaudeCodeBrain:
    """Use Claude Code as the AI backend for analysis and drafting."""

    def analyze_tweet(self, tweet_data: dict) -> dict:
        """Send tweet to Claude Code for analysis."""
        prompt = f"""Analyze this tweet for engagement opportunity:

Tweet: {tweet_data['text']}
Author: @{tweet_data['author']} ({tweet_data['follower_count']} followers)
Engagement: {tweet_data['likes']} likes, {tweet_data['retweets']} RTs
Posted: {tweet_data['created_at']}

Provide:
1. Topic and sentiment
2. Reply opportunity score (1-10)
3. Suggested angles for replies
4. Any risks or considerations"""

        result = subprocess.run(
            ['claude', '--print', '-p', prompt],
            capture_output=True,
            text=True
        )

        return {"analysis": result.stdout}

    def draft_reply(self, tweet_data: dict, voice_profile: dict) -> list:
        """Generate reply drafts using Claude Code."""
        prompt = f"""Draft 3 reply options for this tweet.

Original Tweet: {tweet_data['text']}
Author: @{tweet_data['author']}

My Voice Profile:
- Tone: {voice_profile['tone']}
- Topics: {', '.join(voice_profile['topics'])}
- Style notes: {voice_profile['style_notes']}

Requirements:
- Each reply under 280 characters
- Match my voice profile
- Provide variety (supportive, insightful, witty)

Format as JSON array with "text" and "character_count" fields."""

        result = subprocess.run(
            ['claude', '--print', '-p', prompt],
            capture_output=True,
            text=True
        )

        # Parse JSON from response
        return json.loads(result.stdout)
```

### Pros

- **Keeps existing app architecture**: Add Claude Code as another service
- **Best of both worlds**: Custom UI + Claude's reasoning
- **Flexible integration**: Call Claude Code only when needed
- **Works with existing workflow**: Minimal changes to planned architecture

### Cons

- **Subprocess overhead**: Each call spawns Claude Code process
- **No session continuity**: Each call is independent (no memory)
- **Parsing complexity**: Need to extract structured data from responses
- **Error handling**: Process failures need robust handling
- **Slower than direct API**: Subprocess + model loading overhead

---

## Approach 3: Hooks Integration

### Concept

Use Claude Code's hooks system to react to external events. A background process monitors the feed and triggers Claude Code sessions with context when interesting events occur.

```
+------------------------------------------------------------------+
|                    FEED MONITOR (Background)                      |
|                    Polls every 15 minutes                         |
+------------------------------------------------------------------+
           |
           | Detects event:
           | - VIP posted
           | - High-velocity tweet
           | - Mentioned you
           |
           v
+------------------------------------------------------------------+
|                    NOTIFICATION + CONTEXT                         |
|  1. Desktop notification: "New from @pmarca about AI"            |
|  2. Write context file: ~/.x-feed/context/vip-alert.md           |
|  3. Optionally: Start Claude Code with context                    |
+------------------------------------------------------------------+
           |
           v
+------------------------------------------------------------------+
|                    CLAUDE CODE SESSION                            |
|  SessionStart hook loads: ~/.x-feed/context/vip-alert.md         |
|  User sees: "VIP Alert: @pmarca posted about AI. View context?"  |
+------------------------------------------------------------------+
```

### Hook Configuration

```json
// ~/.claude/settings.json hooks section
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.x-feed/hooks/load-feed-context.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### Context Loading Hook

```bash
#!/bin/bash
# ~/.x-feed/hooks/load-feed-context.sh

CONTEXT_DIR=~/.x-feed/context
ALERT_FILE="$CONTEXT_DIR/pending-alert.md"

# Check for pending alerts
if [ -f "$ALERT_FILE" ]; then
    # Read alert content
    ALERT_CONTENT=$(cat "$ALERT_FILE")

    # Output system message for Claude
    cat <<EOF
{
  "systemMessage": "X-FEED ALERT:\\n$ALERT_CONTENT\\n\\nWould you like me to analyze this or draft a response?"
}
EOF

    # Archive the alert
    mv "$ALERT_FILE" "$CONTEXT_DIR/archive/$(date +%Y%m%d-%H%M%S).md"
fi
```

### Alert Generation (Feed Monitor)

```python
# feed_monitor.py - runs as background service
import sqlite3
from datetime import datetime
from pathlib import Path
import subprocess

def check_for_alerts():
    """Check feed for alert-worthy events."""
    conn = sqlite3.connect("~/.x-feed/feed.db")

    # Check VIP activity
    vip_tweets = conn.execute("""
        SELECT t.*, a.handle, a.display_name
        FROM tweets t
        JOIN followed_accounts a ON t.author_id = a.id
        WHERE a.priority_tier = 'vip'
        AND t.created_at > datetime('now', '-15 minutes')
        AND t.alerted = 0
    """).fetchall()

    for tweet in vip_tweets:
        create_alert("vip", tweet)
        send_notification(f"New from @{tweet['handle']}", tweet['text'][:100])

        # Mark as alerted
        conn.execute("UPDATE tweets SET alerted = 1 WHERE id = ?", (tweet['id'],))

    conn.commit()
    conn.close()

def create_alert(alert_type: str, tweet: dict):
    """Create context file for Claude Code."""
    context_dir = Path.home() / ".x-feed" / "context"
    context_dir.mkdir(parents=True, exist_ok=True)

    alert_content = f"""# {alert_type.upper()} Alert

**Author**: @{tweet['handle']} ({tweet['display_name']})
**Posted**: {tweet['created_at']}
**Engagement**: {tweet['likes']} likes, {tweet['retweets']} RTs

## Tweet Content

{tweet['text']}

## Suggested Actions

- `/x-analyze {tweet['id']}` - Deep analysis
- `/x-reply {tweet['id']}` - Draft a reply
- `/x-save {tweet['id']}` - Save for later
"""

    (context_dir / "pending-alert.md").write_text(alert_content)

def send_notification(title: str, body: str):
    """Send desktop notification."""
    subprocess.run([
        "osascript", "-e",
        f'display notification "{body}" with title "{title}"'
    ])
```

### Pros

- **Event-driven**: Only engage when something interesting happens
- **Non-intrusive**: Background process, notifications on demand
- **Native Claude Code**: Context injected into normal sessions
- **Low overhead**: No always-running integration

### Cons

- **Limited interactivity**: One-way context injection
- **Requires background service**: Feed monitor must run separately
- **Indirect**: Alert -> Notification -> Manual action -> Claude Code
- **Context staleness**: Alert may be stale by time user sees it

---

## Approach 4: Custom Skills

### Concept

Create Claude Code skills that expose feed functionality as slash commands. Users invoke `/x-feed`, `/x-reply`, etc. directly in conversations.

```
+------------------------------------------------------------------+
|                      CLAUDE CODE TERMINAL                         |
+------------------------------------------------------------------+
|  User: /x-feed                                                   |
|                                                                  |
|  [Skill invoked: x-feed]                                         |
|  Loading feed data via shell script...                           |
|                                                                  |
|  Here's your curated feed for the last 4 hours:                  |
|                                                                  |
|  ## VIP Activity                                                 |
|  @pmarca posted about...                                         |
|                                                                  |
|  ## Trending in your network                                     |
|  1. AI agents discussion...                                      |
|                                                                  |
|  User: /x-reply 1923847123 witty                                |
|                                                                  |
|  [Skill invoked: x-reply]                                        |
|  Drafting witty reply to tweet 1923847123...                     |
|                                                                  |
|  Here are 3 options:                                             |
|  1. "Interesting take, but have you considered..."               |
+------------------------------------------------------------------+
```

### Skill Definition

```yaml
# skills/x-feed/SKILL.md
---
name: x-feed
description: Access your curated X/Twitter feed. Use when user says "show feed", "what's happening on X", "x-feed", "twitter feed", or wants to see social media activity. Provides ranked tweets from followed accounts.
---

# X Feed Skill

Show the user's curated Twitter/X feed with ranking and categorization.

## Usage

Run the feed loader script and present results:

```bash
~/.x-feed/bin/get-feed.sh --format=markdown --hours=4 --limit=20
```

## Output Formatting

Present feed in sections:
1. **VIP Activity** - Posts from priority accounts
2. **High Engagement** - Tweets gaining traction
3. **Recent** - Chronological from last few hours

For each tweet show:
- Author (@handle)
- Tweet text (first 200 chars if long)
- Engagement metrics
- Tweet ID for reference

## Follow-up Suggestions

After showing feed, suggest:
- `/x-analyze <id>` - Deep dive on specific tweet
- `/x-reply <id>` - Draft a reply
- `/x-save <id>` - Save for later
```

```yaml
# skills/x-reply/SKILL.md
---
name: x-reply
description: Draft replies to X/Twitter posts. Use when user says "reply to tweet", "x-reply", "draft response to @user", or provides a tweet ID to respond to. Generates voice-matched reply options.
---

# X Reply Skill

Draft contextual replies matching the user's voice profile.

## Arguments

- `tweet_id` (required): ID of tweet to reply to
- `tone` (optional): witty, thoughtful, supportive, contrarian

## Process

1. Fetch tweet context:
```bash
~/.x-feed/bin/get-tweet.sh <tweet_id> --include-thread
```

2. Load voice profile:
```bash
cat ~/.x-feed/voice-profile.json
```

3. Generate 3 reply options considering:
   - Original tweet topic and sentiment
   - Thread context if available
   - User's voice profile
   - Character limit (280)

## Output Format

For each draft:
- Reply text
- Character count
- Why this approach works
- Engagement prediction
```

### Pros

- **Familiar UX**: Slash commands like Discord/Slack
- **Contextual**: Skills have access to conversation context
- **Composable**: Chain skills together
- **Low implementation**: Markdown + shell scripts
- **Discoverable**: Listed in `/help` and skill picker

### Cons

- **Limited data access**: Shell scripts for data fetching
- **No persistent state**: Each invocation independent
- **Manual invocation**: User must know/remember commands
- **Character budget**: Skills compete for 15k character limit

---

## Approach 5: Context Bridging

### Concept

The simplest approach: manually or automatically inject feed context into Claude Code conversations. No special integration needed - just paste relevant data.

```
+------------------------------------------------------------------+
|                      SIMPLE WORKFLOW                              |
+------------------------------------------------------------------+

1. User runs standalone feed viewer:
   $ x-feed --top 5 --format markdown | pbcopy

2. User pastes into Claude Code:
   "Based on this feed snapshot, what should I engage with?"
   [pasted feed data]

3. Claude analyzes and suggests

4. User runs draft command:
   $ x-feed draft-reply 12345 | pbcopy

5. User reviews with Claude:
   "Polish this draft: [pasted draft]"
```

### Automation Helper

```bash
#!/bin/bash
# x-claude - Helper for Claude Code integration

case "$1" in
    feed)
        # Fetch and format feed for pasting
        python -m x_feed.cli feed --format=markdown --hours=4
        ;;
    context)
        # Create context file Claude can read
        python -m x_feed.cli feed --format=markdown > /tmp/x-feed-context.md
        echo "Context saved to /tmp/x-feed-context.md"
        echo "In Claude Code, run: Read /tmp/x-feed-context.md"
        ;;
    tweet)
        # Get specific tweet for analysis
        python -m x_feed.cli tweet "$2" --include-thread --format=markdown
        ;;
esac
```

### Pros

- **Zero integration**: Works with any Claude Code setup
- **Maximum flexibility**: Format context however needed
- **No dependencies**: No MCP, hooks, or skills required
- **Simple mental model**: Copy/paste workflow
- **Full control**: User decides what context to include

### Cons

- **Manual effort**: Requires copy/paste each time
- **No tool access**: Claude can't fetch more data mid-conversation
- **Context rot**: Feed data stale if conversation continues
- **Fragmented workflow**: Switching between tools constantly

---

## Architecture Comparison

### Standalone App vs Claude Code Integrated

```
+------------------------------------------------------------------+
|                    STANDALONE APP ARCHITECTURE                    |
+------------------------------------------------------------------+

+----------------+    +----------------+    +----------------+
|   Web UI       |    |  Feed Service  |    | LLM Service    |
|   (HTMX)       |--->|  (FastAPI)     |--->| (Groq/Claude)  |
+----------------+    +----------------+    +----------------+
                              |
                              v
                      +----------------+
                      |    SQLite      |
                      |    + Twitter   |
                      +----------------+

Pros:                         Cons:
+ Custom UI                   - Build everything from scratch
+ Works standalone            - Separate LLM API costs ($5-20/mo)
+ Can run headless            - Context limited to app's design
+ Traditional web app         - No Claude Code integration

+------------------------------------------------------------------+
|               CLAUDE CODE + MCP SERVER ARCHITECTURE               |
+------------------------------------------------------------------+

+----------------+    +----------------+    +----------------+
|  Claude Code   |    |  MCP Server    |    |   Data Layer   |
|  (Terminal)    |<-->|  (x-feed)      |--->|  SQLite+API    |
+----------------+    +----------------+    +----------------+
       |
       | Natural Language
       v
+----------------+
| Your Feed,     |
| Analysis,      |
| Draft Replies  |
+----------------+

Pros:                         Cons:
+ Zero LLM cost               - Terminal-only interface
+ Full Claude reasoning       - Must run MCP server
+ Conversational              - Learning curve for tools
+ Composable with other tools - No persistent UI
+ Session memory              - Requires Claude Code

+------------------------------------------------------------------+
|                    HYBRID ARCHITECTURE                            |
+------------------------------------------------------------------+

+----------------+    +----------------+    +----------------+
|   Web UI       |    |  MCP Server    |    |   Data Layer   |
|   (optional)   |<-->|  (shared)      |<-->|  SQLite+API    |
+----------------+    +----------------+    +----------------+
                              ^
                              |
                      +----------------+
                      |  Claude Code   |
                      |  (for AI)      |
                      +----------------+

Best of both:
+ Simple web UI for browsing
+ Claude Code for AI-powered features
+ Shared data layer
+ Choose interface per task
```

### Feature Matrix

| Feature | Standalone | MCP Server | Hooks | Skills | Context Bridge |
|---------|------------|------------|-------|--------|----------------|
| Custom UI | Yes | No | No | No | External |
| LLM Cost | $5-20/mo | $0 | $0 | $0 | $0 |
| Real-time feed | Yes | Yes | Events | Manual | Manual |
| Claude reasoning | Limited | Full | Full | Full | Full |
| Session memory | No | Yes | No | No | Yes |
| Background alerts | Yes | No | Yes | No | External |
| Tool composition | No | Yes | Limited | Yes | No |
| Implementation effort | High | Medium | Low | Low | Very Low |

---

## Recommendation

### For a Local Personal Tool: MCP Server Integration

**Why MCP Server is the best approach:**

1. **Natural interaction**: Ask questions in plain English
   - "What did my VIPs post today?"
   - "Summarize the AI discussion in my feed"
   - "Draft a thoughtful reply to this thread"

2. **Zero marginal cost**: Uses Claude Code subscription you already have

3. **Full Claude reasoning**:
   - Not limited to prompt templates
   - Can ask follow-up questions
   - Multi-step analysis naturally

4. **Composable**: Combine with other tools
   - "Find tweets about topic X, then help me write a blog post"
   - "Analyze this thread and create a summary for my notes"

5. **Maintainable**:
   - Server is just Python/Node
   - Tools are independent functions
   - Easy to add new capabilities

### Implementation Roadmap

```
Phase 1: Core MCP Server (Week 1)
├── Set up FastMCP server skeleton
├── Implement get_feed tool with SQLite backend
├── Implement get_thread tool
├── Add to Claude Code via .mcp.json
└── Test basic feed browsing

Phase 2: Feed Monitoring (Week 2)
├── Background service for API polling
├── SQLite schema for tweets + accounts
├── Ranking algorithm
├── VIP categorization
└── get_trending, get_vip_activity tools

Phase 3: Engagement Tools (Week 3)
├── draft_reply tool with voice profile
├── draft_post tool
├── analyze_tweet tool
├── save_for_later + get_saved_items
└── Voice profile configuration

Phase 4: Polish (Week 4)
├── Add Skills for common workflows (/x-feed, /x-reply)
├── SessionStart hook for pending alerts
├── Desktop notifications for VIPs
└── Documentation and refinement
```

### Example Session

```
$ claude

You: /x-feed

[x-feed skill invoked]

Here's your curated feed for the last 4 hours:

## VIP Activity (3 new)

1. @pmarca (1h ago) - 234 likes
   "The most underrated skill in tech is..."
   ID: 1923847123

2. @naval (2h ago) - 1.2K likes
   Thread on building wealth: "Specific knowledge is..."
   ID: 1923841111

3. @paulg (3h ago) - 567 likes
   "The best founders I know have this trait..."
   ID: 1923835555

## Trending in Your Network

AI Agents (47 tweets) - Debate about autonomy levels
TypeScript 5.4 (23 tweets) - New features discussion

Would you like me to analyze any of these or draft a reply?

You: Analyze the pmarca tweet and suggest a reply angle

[Calling analyze_tweet for 1923847123...]

## Analysis: @pmarca on Underrated Skills

**Topic**: Career/skill development in tech
**Sentiment**: Thoughtful, advisory
**Thread context**: Standalone tweet, high engagement rate

**Key observations**:
- Engagement spike suggests resonance
- Comments split between agreements and "what about X?"
- Good opportunity for substantive addition

**Suggested angles**:
1. **Add to the list**: Share another underrated skill with brief why
2. **Concrete example**: Agree + share specific story demonstrating it
3. **Thoughtful pushback**: "Underrated, but becoming recognized as..."

Based on your voice profile (technical, occasionally witty), I'd suggest angle #1 or #2.

You: Draft 3 replies using angle 1 - add writing as underrated skill

[Calling draft_reply with angle context...]

Here are 3 options:

1. **Direct addition** (187 chars)
   "Writing. Not blog posts, but the ability to explain complex technical
   concepts clearly in 3 sentences. It's how senior engineers actually
   get things done."

2. **With hook** (203 chars)
   "Writing, specifically - explaining complex things simply. The engineer
   who can turn a 50-page spec into a clear Slack message moves faster
   than anyone with better code."

3. **Contrarian angle** (195 chars)
   "Writing is #1 for me. Not content creation - internal writing. The
   best engineers I know spend more time on docs and proposals than code.
   It compounds."

Which would you like to refine, or should I draft alternatives?
```

---

## Code Snippets Reference

### Complete MCP Tool Definitions (TypeScript)

```typescript
// x-feed-server/src/tools.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

export function registerTools(server: McpServer) {
  // Get Feed Tool
  server.tool(
    "get_feed",
    {
      count: z.number().optional().default(20),
      category: z.string().optional().default("all"),
      hours: z.number().optional().default(24),
    },
    async ({ count, category, hours }) => {
      const tweets = await fetchFromDatabase(category, hours, count);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(tweets, null, 2),
          },
        ],
      };
    }
  );

  // Draft Reply Tool
  server.tool(
    "draft_reply",
    {
      tweet_id: z.string(),
      tone: z.enum(["witty", "thoughtful", "supportive", "contrarian", "default"]).optional(),
      angle: z.string().optional(),
    },
    async ({ tweet_id, tone, angle }) => {
      const tweet = await getTweet(tweet_id);
      const voiceProfile = await loadVoiceProfile();
      const drafts = await generateDrafts(tweet, voiceProfile, tone, angle);

      return {
        content: [
          {
            type: "text",
            text: formatDrafts(drafts),
          },
        ],
      };
    }
  );

  // Analyze Tweet Tool
  server.tool(
    "analyze_tweet",
    {
      tweet_id: z.string(),
    },
    async ({ tweet_id }) => {
      const tweet = await getTweet(tweet_id);
      const thread = await getThreadContext(tweet_id);
      const authorHistory = await getAuthorContext(tweet.author_id);

      const analysis = {
        topic: extractTopic(tweet),
        sentiment: analyzeSentiment(tweet),
        engagement: {
          rate: calculateEngagementRate(tweet),
          velocity: calculateVelocity(tweet),
        },
        thread_context: summarizeThread(thread),
        reply_opportunities: identifyAngles(tweet, thread),
        risks: identifyRisks(tweet),
      };

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(analysis, null, 2),
          },
        ],
      };
    }
  );
}
```

### Skill File Template

```markdown
---
name: x-feed
description: Show curated X/Twitter feed. Use for "show feed", "what's on twitter", "x-feed", or checking social media. Displays ranked tweets from followed accounts with engagement options.
---

# X Feed

Display the user's curated Twitter feed.

## Quick Command

```bash
SH=~/.x-feed/bin/x-feed.sh
$SH feed --format=markdown --hours=4
```

## Presentation

After running the command, present results as:

1. **VIP Activity** - Priority accounts (if any new posts)
2. **High Engagement** - Tweets gaining traction
3. **Recent** - Last few hours chronologically

Include for each tweet:
- Author with handle
- Preview (first 200 chars)
- Engagement (likes/RTs)
- ID for reference

## Follow-ups

Suggest: `/x-analyze <id>`, `/x-reply <id>`, `/x-save <id>`
```

---

## Conclusion

For a personal local tool, **MCP Server integration** offers the best balance of power and simplicity. You get Claude's full reasoning capabilities, natural language interaction, zero marginal LLM costs, and seamless integration with your development workflow in Claude Code.

Start with a basic MCP server exposing 3-4 core tools (get_feed, get_thread, draft_reply, analyze_tweet), then expand based on actual usage patterns. The investment in building the MCP server pays off quickly through the natural, conversational workflow it enables.

---

*Last updated: January 2026*
*Status: Research Complete - Ready for Implementation*
