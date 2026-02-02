# X Feed Monitor & Engagement Assistant - Project Synthesis

## Executive Summary

**What we're building**: A local-only desktop application that monitors your X/Twitter feed, surfaces the most relevant content from 1000+ followed accounts, and helps you transition from a 10-year lurker to an active participant through AI-assisted reply suggestions and original post drafting.

**Why this approach**:
- **Local-first**: All data stays on your machine - no cloud storage of your social graph or engagement patterns
- **Third-party API**: Official X API is $200/month for read access; third-party alternatives (TwitterAPI.io) offer 96% cost savings at ~$3-15/month
- **Python + SQLite**: Fastest development path with battle-tested libraries (Tweepy patterns), zero external dependencies
- **Groq for AI**: Best price/performance ratio for LLM inference (~$5/month for personal use), with Claude as optional upgrade for complex tasks
- **Web UI via FastAPI + HTMX**: No frontend build tooling, opens in any browser, can wrap as desktop app if desired

---

## Recommended Architecture

```
+------------------------------------------------------------------+
|                         USER INTERFACE                            |
|                    (FastAPI + HTMX + Jinja2)                      |
|     localhost:8000 in browser or wrapped with flaskwebgui        |
+------------------------------------------------------------------+
                                |
                                v
+------------------------------------------------------------------+
|                      APPLICATION LAYER                            |
+------------------------------------------------------------------+
|  +----------------+  +----------------+  +-------------------+   |
|  | Feed Service   |  | AI Service     |  | Engagement Service|   |
|  |----------------|  |----------------|  |-------------------|   |
|  | - Fetch feed   |  | - Summarize    |  | - Draft replies   |   |
|  | - Rank content |  | - Analyze tone |  | - Draft posts     |   |
|  | - Categorize   |  | - Voice match  |  | - Track progress  |   |
|  +----------------+  +----------------+  +-------------------+   |
+------------------------------------------------------------------+
                                |
                                v
+------------------------------------------------------------------+
|                         DATA LAYER                                |
|  +-------------------+  +--------------------+                    |
|  | SQLite Database   |  | File Storage       |                    |
|  |-------------------|  |--------------------|                    |
|  | - Tweets          |  | - Voice profile    |                    |
|  | - Accounts        |  | - Drafts           |                    |
|  | - Interactions    |  | - Preferences      |                    |
|  | - Saved items     |  |                    |                    |
|  +-------------------+  +--------------------+                    |
+------------------------------------------------------------------+
                                |
                                v
+------------------------------------------------------------------+
|                      EXTERNAL SERVICES                            |
|  +-------------------+  +-------------------+                     |
|  | Twitter Data API  |  | LLM API           |                     |
|  | (TwitterAPI.io)   |  | (Groq / Claude)   |                     |
|  +-------------------+  +-------------------+                     |
+------------------------------------------------------------------+
```

**Key flows**:
1. **Feed Monitoring**: APScheduler polls TwitterAPI.io every 15 minutes -> stores in SQLite -> ranks by engagement/relevance/recency -> displays in UI
2. **AI Assistance**: User selects tweet -> sends to Groq with voice profile -> returns draft replies/analysis
3. **Engagement Tracking**: User interactions logged -> builds personal analytics -> informs ranking algorithm

---

## Technology Choices (with rationale)

| Layer | Choice | Why | Alternatives Considered |
|-------|--------|-----|------------------------|
| **API Access** | TwitterAPI.io | $0.15/1K tweets (~$3-15/mo), no approval needed, simple REST API | Official API ($200/mo - overkill), Nitter (unreliable since 2024), browser scraping (brittle) |
| **Backend Language** | Python 3.11+ | Fastest development, best Twitter libraries (Tweepy patterns), rich ecosystem | TypeScript (viable but more setup), Go (better distribution but slower dev), Rust (overkill) |
| **Web Framework** | FastAPI | Async support, auto-generated API docs, 3-5x faster than Flask, pairs perfectly with HTMX | Flask (simpler but slower), Django (too heavy) |
| **Database** | SQLite + aiosqlite | Zero config, single file, ACID compliant, perfect for local apps, FTS5 for search | DuckDB (only if analytics-heavy), PostgreSQL (overkill for local) |
| **UI Approach** | HTMX + Jinja2 | Zero JavaScript build tooling, server-side rendering with partial updates, works in any browser | Tauri (better UX but requires Rust), Electron (100MB+ bloat), CLI (less friendly) |
| **AI/LLM** | Groq (Llama 3.3 70B) primary | Ultra-fast inference (1200 tok/s), $0.59/$0.79 per 1M tokens, excellent quality | Claude Sonnet (better quality, 5-6x cost), local Ollama (free but requires GPU), OpenAI (more expensive) |
| **Scheduling** | APScheduler | In-process, async support, can persist to SQLite, no external services | Celery (requires Redis - overkill), cron (less flexible) |
| **Notifications** | desktop-notifier | Cross-platform, async API, action buttons, pure Python | plyer (less features), native OS APIs (more complex) |

---

## Core Features (MVP)

### Phase 1: Feed Monitoring (Week 1-2)
| Priority | Feature | Description |
|----------|---------|-------------|
| P0 | Feed fetching | Poll followed accounts every 15 min via TwitterAPI.io |
| P0 | Local storage | Cache tweets in SQLite with full metadata |
| P0 | Basic ranking | Sort by: engagement score + recency decay (half-life 6 hours) |
| P0 | Web UI | Display ranked feed at localhost:8000 |
| P1 | Account categorization | Import Twitter Lists, manual priority tiers (VIP/Important/Normal) |
| P1 | Thread reconstruction | Fetch full threads via conversation_id |

### Phase 2: AI Integration (Week 3-4)
| Priority | Feature | Description |
|----------|---------|-------------|
| P0 | Tweet analysis | Summarize topic, sentiment, engagement opportunity |
| P0 | Reply suggestions | Generate 3 voice-matched reply options |
| P0 | Voice profile | Store user's tone preferences, topics, style notes |
| P1 | Feed summarization | Daily digest of top conversations and trends |
| P1 | Original post drafting | Generate post ideas based on trending topics |

### Phase 3: Engagement Workflow (Week 5-6)
| Priority | Feature | Description |
|----------|---------|-------------|
| P0 | Save queue | Bookmark tweets for later engagement with scheduling |
| P0 | Draft storage | Save and iterate on replies/posts before publishing |
| P1 | Smart notifications | Desktop alerts for VIP accounts and high-velocity tweets |
| P1 | Engagement tracking | Log likes, replies, posts for analytics |
| P2 | Posting integration | Optional: post replies/tweets via official free tier (1.5K/mo limit) |

---

## Innovative Features (Post-MVP)

Ranked by impact vs implementation complexity:

| Rank | Feature | Impact | Complexity | Description |
|------|---------|--------|------------|-------------|
| 1 | **Reply Gym** | High | Medium | Practice replies on real tweets without posting. AI analyzes tone, predicts engagement. Build confidence before going live. |
| 2 | **Engagement Gamification** | High | Simple | Achievement badges, daily quests, XP system. "First Reply," "7-day streak," progress visualization. Anti-addiction design. |
| 3 | **Gentle Reentry Protocol** | High | Simple | Lurker-specific onboarding. Start with <5K follower accounts, exposure control, "pause button," weekly reflection. |
| 4 | **Archive Archaeology** | Medium | Complex | Analyze 10 years of likes/bookmarks to build interest graph. "Digital Identity Report" visualization. Surface forgotten gems. |
| 5 | **Voice Discovery Workshop** | Medium | Medium | Interactive quiz to find your archetype. Style experiments, anti-persona builder, inspiration library. |
| 6 | **Draft Workshop + AI Coach** | Medium | Medium | Multi-angle feedback, audience simulator, take temperature, timing advisor, courage meter for aging drafts. |
| 7 | **Serendipity Engine** | Medium | Complex | Weak tie detection, conversation bridging opportunities, lurker-to-lurker matching, reply opportunity scoring. |
| 8 | **Relationship Map** | Low | Complex | Interactive D3.js visualization of your social graph. Cluster detection, influence flows, entry point identification. |
| 9 | **Content Calendar** | Low | Medium | Event integration, trend prediction, engagement budgeting, retrospective view. |
| 10 | **Voice Consistency Sentinel** | Low | Medium | Drift detection, pre-post tone check, burnout indicators. Only valuable once actively posting. |

**Recommendation**: Start with Reply Gym + Gamification + Gentle Reentry - these directly address lurker psychology with relatively simple implementation.

---

## Data Model

### Core Entities

```
+------------------+       +------------------+       +------------------+
|  followed_accounts|       |      tweets      |       | user_interactions|
+------------------+       +------------------+       +------------------+
| id (PK)          |       | id (PK)          |       | id (PK)          |
| twitter_user_id  |<---+  | twitter_tweet_id |       | tweet_id (FK)    |
| handle           |    |  | author_id (FK)   |------>| interaction_type |
| display_name     |    |  | text             |       | interacted_at    |
| priority_tier    |    |  | conversation_id  |       | time_to_interact |
| categories[]     |    |  | in_reply_to_id   |       | session_id       |
| relevance_score  |    |  | likes, retweets  |       +------------------+
| avg_engagement   |    |  | engagement_score |
+------------------+    |  | relevance_score  |
        |               |  | detected_topics[]|
        |               |  | twitter_created  |
        v               |  +------------------+
+------------------+    |
|    categories    |    |
+------------------+    |
| id (PK)          |    |      +------------------+
| name             |    |      |   saved_items    |
| type             |    |      +------------------+
| twitter_list_id  |    +----->| id (PK)          |
| notification_lvl |           | tweet_id (FK)    |
+------------------+           | reason           |
                               | tags[]           |
                               | scheduled_for    |
                               | status           |
                               | snapshot (JSON)  |
                               +------------------+
```

### Key Relationships
- **followed_accounts** 1:N **tweets** (author_id)
- **tweets** 1:N **user_interactions** (tweet_id)
- **tweets** 1:N **saved_items** (tweet_id)
- **categories** N:M **followed_accounts** (via category_memberships)
- **tweets** self-reference via conversation_id for threads

### Storage Estimates (1000 follows, 6 months retention)
- Tweets: ~500K rows, ~200MB
- Interactions: ~50K rows, ~20MB
- Total SQLite file: ~250MB

---

## Cost Estimate

### Monthly Running Costs (Personal Local App)

| Service | Usage Estimate | Cost |
|---------|----------------|------|
| **TwitterAPI.io** | 20K requests/month (5 accounts polled every 15 min + thread fetches) | $3-5 |
| **Groq API** | 100 analyses + 50 replies/day = ~50K tokens/day | $3-5 |
| **Claude API** (optional) | 10 complex analyses/day | $5-10 |
| **Electricity** | Local compute | ~$1 |
| **Total** | | **$7-21/month** |

### Comparison to Alternatives
| Option | Monthly Cost |
|--------|--------------|
| This project | $7-21 |
| Official X API Basic | $200 |
| Official X API + Claude only | $225+ |
| Manual browsing (time cost) | Priceless hours lost |

### Break-Even Analysis
If you value your time at $50/hour, this app pays for itself if it saves you more than 30 minutes per month through better curation and AI-assisted engagement.

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
**Goal**: Working feed monitor with basic UI

| Task | Dependencies | Effort |
|------|--------------|--------|
| Project setup (Python, FastAPI, SQLite) | None | 2h |
| TwitterAPI.io integration | API key | 4h |
| Database schema + migrations | None | 3h |
| APScheduler for polling | Database | 2h |
| Basic ranking algorithm | Database | 4h |
| HTMX feed display | All above | 6h |
| Account categorization UI | Feed display | 4h |

**Deliverable**: Can view ranked feed at localhost:8000

### Phase 2: AI Integration (Weeks 3-4)
**Goal**: AI-powered analysis and suggestions

| Task | Dependencies | Effort |
|------|--------------|--------|
| Groq API integration | Phase 1 | 3h |
| Voice profile definition | None | 2h |
| Tweet analysis prompts | Groq integration | 4h |
| Reply suggestion prompts | Voice profile | 4h |
| Feed summarization | Tweet analysis | 3h |
| UI for AI features | All above | 6h |

**Deliverable**: Can analyze tweets and get reply suggestions

### Phase 3: Engagement Workflow (Weeks 5-6)
**Goal**: Full engagement preparation pipeline

| Task | Dependencies | Effort |
|------|--------------|--------|
| Save queue implementation | Phase 1 | 4h |
| Draft storage + versioning | Phase 2 | 4h |
| Smart notifications | Phase 1 | 4h |
| Engagement tracking | Database | 3h |
| Analytics dashboard | Engagement tracking | 6h |
| Optional: Posting via free tier | OAuth setup | 4h |

**Deliverable**: Complete MVP ready for daily use

### Phase 4: Lurker Features (Weeks 7-8+)
**Goal**: Features specifically for building confidence

| Task | Dependencies | Effort |
|------|--------------|--------|
| Reply Gym (practice mode) | Phase 2 | 8h |
| Achievement system | Engagement tracking | 6h |
| Gentle reentry flow | UI foundation | 4h |
| Progress visualization | Achievement system | 4h |

**Deliverable**: Lurker-to-contributor journey tools

---

## Open Questions / Decisions Needed

### Must Decide Before Starting

| Question | Options | Recommendation |
|----------|---------|----------------|
| **API provider** | TwitterAPI.io vs SocialData.tools vs Bright Data | Start with TwitterAPI.io (best documented, pay-as-you-go) |
| **LLM provider** | Groq-only vs Groq+Claude hybrid vs Local Ollama | Groq-only for MVP; add Claude for voice matching if Groq quality insufficient |
| **Posting capability** | Include posting (requires official API free tier OAuth) or read-only? | Include - the goal is engagement, but make it optional |
| **UI packaging** | Browser-only vs flaskwebgui wrapper vs full Tauri | Browser-only for MVP; consider flaskwebgui wrapper post-MVP |

### Can Decide Later

| Question | When to Decide |
|----------|----------------|
| RAG for tweet history? | After MVP - may be overkill for personal use |
| Fine-tune voice model? | After 500+ engagement examples collected |
| Mobile access? | Only if daily use proves valuable |
| Multi-account support? | If user requests it |

### User Input Requested

1. **VIP accounts**: Which 10-20 accounts should trigger immediate notifications?
2. **Topic priorities**: What tech topics matter most? (e.g., AI/ML, TypeScript, startups, open source)
3. **Voice aspirations**: Any accounts whose tone/style you admire and want to emulate?
4. **Engagement goals**: Replies only? Original posts too? Quote tweets?
5. **Time budget**: How many minutes/day do you want to spend engaging?

---

## References

### Source Documents
1. [01-api-options.md](./01-api-options.md) - X/Twitter API evaluation, pricing, authentication, third-party alternatives
2. [02-tech-stack.md](./02-tech-stack.md) - Language, database, UI framework, scheduling, notification options
3. [03-ai-integration.md](./03-ai-integration.md) - Local vs cloud LLMs, prompt patterns, RAG, fine-tuning, cost analysis
4. [04-feed-monitoring.md](./04-feed-monitoring.md) - Ranking algorithms, categorization, notifications, thread reconstruction, data model
5. [05-innovative-features.md](./05-innovative-features.md) - Lurker-specific features: Reply Gym, gamification, confidence building

### Key External Resources
- [TwitterAPI.io Documentation](https://twitterapi.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [HTMX Documentation](https://htmx.org/)
- [Groq API](https://groq.com/)
- [APScheduler Documentation](https://apscheduler.readthedocs.io/)
- [Tweepy Documentation](https://docs.tweepy.org/) (for code patterns, even if using third-party API)

---

*Last updated: January 2025*
*Status: Ready for implementation*
