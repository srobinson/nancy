# Archive Archaeology: Deep Dive

*Turning 10 Years of Silent Curation into Your Authentic Voice*

---

## The Core Insight

You have never posted a tweet. But you have *curated* for a decade.

Every like was a vote. Every bookmark was a "this matters." Every follow was a commitment to listen. Every unfollow was a boundary. You made thousands of micro-decisions about what deserves your attention, and those decisions reveal something profound: **you already have a voice. You just haven't spoken it yet.**

Archive Archaeology is the feature that mines this goldmine.

---

## 1. The Psychological Insight

### Why Passive Engagement is Valuable Signal

Most people think their Twitter likes are throwaway gestures. They're not. They're one of the most honest signals of authentic interest that exists online.

**The Honesty of the Like Button**

When you write a tweet, you're performing. You're thinking about:
- How will this make me look?
- Will people judge me for this opinion?
- Is this the "right" take?
- Will this harm my professional reputation?

When you like a tweet, you're usually not thinking about any of that. You're just... resonating. The like is instinctive, pre-cognitive, honest. Over 10 years and thousands of likes, patterns emerge that reveal your *actual* interests, not your performed ones.

**The Gap Between Stated and Revealed Preferences**

Behavioral economics has a term for this: **revealed preferences** vs. **stated preferences**.

- **Stated preference**: "I'm really interested in machine learning and distributed systems."
- **Revealed preference** (from your likes): You engage 3x more with posts about developer experience and tooling than pure ML theory. You love dry humor about tech culture. You're fascinated by indie hackers more than enterprise software.

This gap is not a contradiction - it's discovery. Archive Archaeology surfaces what you're actually drawn to, which may surprise you.

**The Subconscious Curator**

After 10 years of consuming content, you've developed sophisticated taste without realizing it. You can instantly tell:
- Which threads will be worth reading
- Which accounts are performative vs. genuine
- Which takes are insightful vs. contrarian for attention
- Which technical explanations will be clear vs. confusing

This is *expertise*. You are an expert curator. You just never noticed because you never had to articulate it.

### The Lurker's Advantage

There's a hidden superpower in being a long-time lurker: **you developed taste without developing a persona.**

Active posters face a problem: every post shapes their public identity. Over time, they get locked into their "brand." The hot-take person keeps taking hot takes. The thread guy keeps writing threads. They become their output.

You have no such constraints. Your taste developed purely, shaped only by what genuinely resonated with you. No audience capture. No engagement addiction. No persona lock-in.

When you finally speak, you can speak authentically - because you never trained yourself to perform.

### The "I Have Nothing to Say" Paradox

Lurkers often feel they have nothing to contribute. Archive Archaeology reveals the opposite: you have *opinions* about everything. You just haven't noticed.

Consider: when you scrolled past 1000 tweets about JavaScript frameworks and liked exactly 47 of them, you made 1000 editorial decisions. You have strong opinions about what makes a good JS framework take. You're just not conscious of them.

The feature's job is to make you conscious of your own taste.

---

## 2. What Data to Mine

### Primary Data Sources

#### Liked Tweets

This is the richest vein. Each like is a vote of resonance.

**What to Extract:**
- Full tweet text and media
- Author information (follower count, bio, account type)
- Timestamp of the original tweet
- Timestamp of your like (important: was it immediate or did you like it days later?)
- Engagement metrics at time of like (were you early or following the crowd?)
- Thread position (was it a standalone tweet, thread opener, or reply?)
- Quote tweet context if applicable

**Signal Value:** HIGH - This is your unfiltered interest graph

#### Bookmarks

Bookmarks are even more intentional than likes. A bookmark says: "I want to return to this."

**What to Extract:**
- Tweet content and metadata (same as likes)
- Time between bookmark and any subsequent access
- Whether you ever returned to the bookmark
- Categorization if you use bookmark folders

**Signal Value:** VERY HIGH - These are your "important to me" signals

**What Bookmarks Reveal That Likes Don't:**
- **Reference material**: Technical explanations you wanted to remember
- **Action items**: Threads about tools you wanted to try
- **Aspirational content**: Posts about skills you want to develop
- **"I'll need this in an argument"**: Takes that articulated something you believe but couldn't phrase yourself

#### Follow/Unfollow History

Your follow decisions are commitments. Your unfollows are boundaries.

**What to Extract:**
- Current follows with follow date
- Unfollowed accounts (if recoverable from archive)
- Follow source (did you find them from a viral tweet? A recommendation? A reply?)
- Engagement level post-follow (did you actually engage with their content?)

**Signal Value:** MEDIUM-HIGH - Shows who you chose to listen to

**What Follow Patterns Reveal:**
- **Communities you joined**: Tech Twitter, Indie Hackers, AI researchers
- **Phases of interest**: You followed 50 blockchain accounts in 2021, unfollowed 40 by 2023
- **Signal vs. noise tolerance**: Do you follow high-volume posters or curated accounts?
- **Social boundaries**: What made you unfollow? Controversy? Volume? Drift?

#### Retweets (Including Quote Tweets)

For a lurker, retweets are rare but significant. A retweet says: "I want my (zero) followers to see this."

**What to Extract:**
- Retweeted content
- Quote tweet text (if any)
- Context: what was happening when you chose to amplify this?

**Signal Value:** VERY HIGH for lurkers - These were moments you almost became a poster

#### Time Patterns

When you engage reveals as much as what you engage with.

**What to Extract:**
- Day of week patterns
- Time of day patterns
- Session duration (quick scroll vs. deep dive)
- Gap between tweet posting and your engagement (immediate? days later?)
- Correlation with external events (conferences, releases, news cycles)

**Signal Value:** MEDIUM - Reveals your Twitter "mode" and optimal engagement windows

### Secondary Data Sources

#### Reply Drafts (if recoverable)
- Any replies you started but abandoned
- These are the "almost posted" moments - incredibly valuable

#### Search History (if available)
- What did you actively seek out?
- Shows intentional interest vs. algorithmic feeding

#### List Memberships
- Lists you created or joined
- Shows how you mentally categorize accounts

#### Muted/Blocked Accounts
- What did you actively reject?
- Defines the negative space of your interests

---

## 3. Analysis Techniques

### Topic Clustering

**Goal:** Discover the 5-10 themes that actually define your interests

**Methodology:**
1. Extract all tweet text from likes/bookmarks
2. Use embedding models (e.g., OpenAI embeddings, sentence-transformers) to vectorize
3. Apply clustering (HDBSCAN works well for variable-density clusters)
4. Use LLM to name and characterize each cluster
5. Calculate cluster sizes and engagement intensity

**Output Example:**
```
Your Interest Clusters (by engagement volume):

1. Developer Experience & Tooling (23% of engagement)
   - "How to make dev tools that don't suck"
   - Key themes: DX, CLI design, error messages, documentation

2. Indie Building & Bootstrapping (19%)
   - "The quiet path to sustainable software businesses"
   - Key themes: MRR, solo founders, pricing, marketing for devs

3. Distributed Systems (Practical) (15%)
   - "Making databases behave"
   - Key themes: Postgres, consistency, performance, war stories

4. Tech Industry Culture Critique (12%)
   - "Calling out the bullshit"
   - Key themes: VC skepticism, hustle culture, interviewing practices

5. Programming Language Aesthetics (9%)
   - "Why some code feels right"
   - Key themes: Rust, type systems, language design, ergonomics
```

**Interesting Patterns to Surface:**
- Clusters that surprise the user ("I didn't realize I cared this much about X")
- Clusters that evolved over time
- Clusters that are underdeveloped (latent interests?)

### Author Affinity Analysis

**Goal:** Identify whose voice resonates most with yours

**Methodology:**
1. Rank authors by total engagement (likes + bookmarks + retweets)
2. Weight by consistency (engaging once with viral thread < engaging regularly)
3. Analyze what makes these authors similar
4. Cluster authors into "voice types" you respond to

**Output Example:**
```
Your Most-Engaged Authors:

Tier 1: Core Resonance (10+ engagements, consistent over years)
- @author1 - "The thoughtful practitioner" - senior eng sharing real learnings
- @author2 - "The dry observer" - cultural commentary with subtle humor
- @author3 - "The generous teacher" - makes complex things accessible

Tier 2: Strong Interest (5-10 engagements)
[...]

What These Authors Share:
- Writing style: Accessible but not dumbed down
- Tone: Confident without being aggressive
- Content: Practice over theory, lessons over proclamations
- Format: Threads preferred over one-liners
```

### Sentiment & Style Analysis

**Goal:** Understand what emotional tenor and writing style resonates with you

**Methodology:**
1. Classify liked tweets by sentiment (positive/negative/neutral)
2. Classify by style dimensions:
   - Serious <-> Humorous
   - Technical <-> Accessible
   - Assertive <-> Tentative
   - Original thinking <-> Curation/synthesis
   - Hot take <-> Measured analysis
3. Analyze tweet structure preferences:
   - Thread vs. single tweet
   - Text-only vs. media-rich
   - Personal anecdote vs. abstract principle

**Output Example:**
```
Your Style Affinities:

Sentiment Distribution:
- 45% Constructive/Positive ("Here's what works")
- 30% Critical/Negative ("Here's what's broken")
- 25% Neutral/Observational ("Here's what I noticed")

Style Profile:
- Technical accessibility: 7/10 (you like technical content made approachable)
- Humor appreciation: 6/10 (you like wit, but not shitposting)
- Hot take tolerance: 4/10 (you prefer nuanced takes)
- Thread preference: 8/10 (you love a good thread)
- Personal narrative: 7/10 (you appreciate when people share their own experience)

What This Suggests For Your Voice:
You likely resonate with content that is technical but accessible, confident but
not aggressive, and grounded in real experience rather than abstract takes.
```

### Evolution Over Time

**Goal:** Track how your interests and preferences have shifted

**Methodology:**
1. Divide engagement history into periods (years, or significant life phases)
2. Run all analyses per-period
3. Identify:
   - Stable interests (present throughout)
   - Emerging interests (growing over time)
   - Fading interests (peaked and declined)
   - Phase-specific interests (intense but temporary)

**Output Example:**
```
Your Interest Evolution (2014-2024):

Stable Throughout:
- Developer tooling (consistent passion)
- Tech industry critique (always engaged)

Major Shifts:
- 2014-2017: Heavy JavaScript ecosystem engagement
- 2018-2020: Growing interest in Rust and systems programming
- 2021-2022: Spike in crypto/web3 (now faded 80%)
- 2022-2024: Emerging interest in AI/ML tooling

Interpretation:
Your core interest is "making things better for developers" - the specific
technologies change, but you consistently engage with content about improving
the developer experience. This is your through-line.
```

### Style Fingerprinting

**Goal:** Extract a writing style "DNA" that characterizes your taste

**Methodology:**
1. Analyze liked tweets for:
   - Sentence length distribution
   - Vocabulary complexity
   - Use of jargon vs. plain language
   - Rhetorical patterns (questions, lists, callbacks)
   - Emoji/punctuation patterns
2. Build a composite "style signature" from what you engage with most

**Output Example:**
```
Style Fingerprint of Content You Love:

Sentence Style:
- Average length: 15-20 words (neither curt nor verbose)
- Varied rhythm (mixes short punchy with longer explanatory)

Vocabulary:
- Technical terms: Uses them but explains them
- Jargon density: Medium (insider but not gatekeeping)
- Formality: Professional-casual blend

Rhetorical Patterns You Engage With:
- "Here's what I learned..." (experience-based authority)
- "Unpopular opinion:" (confident disagreement)
- "The thing nobody talks about is..." (insight revelation)
- Questions that make you think (not rhetorical dunking)

Format Preferences:
- Threads: 3-7 tweets (not too short, not sprawling)
- Visuals: Diagrams and screenshots > memes
- Links: To code/projects > to articles
```

---

## 4. Output: The Voice Profile

### What Gets Generated

Archive Archaeology produces a comprehensive **Voice Profile Document** - a mirror that shows you who you are based on what you've chosen to engage with.

### Voice Profile Structure

```markdown
# Your Voice Profile
Generated from 10 years of engagement | 4,847 likes | 312 bookmarks | 23 retweets

## Executive Summary

You are a **Thoughtful Practitioner** with deep interest in developer experience,
a taste for dry humor, and strong opinions about how software should be built.
You value substance over hype, learning over proclamation, and real experience
over abstract theory.

Your engagement pattern suggests you'd thrive as someone who:
- Shares practical learnings from real work
- Offers nuanced takes on tech culture and trends
- Bridges technical depth with accessibility
- Occasionally drops devastating one-liners about industry BS

## Your Interest Map

[Visual: Concentric circles showing core vs. peripheral interests]

### Core Interests (70% of engagement)
1. Developer Experience & Tooling
2. Indie Bootstrapping & Sustainable Business
3. Practical Distributed Systems

### Strong Interests (20% of engagement)
4. Tech Culture & Industry Critique
5. Programming Language Design
6. Engineering Leadership & Management

### Peripheral Interests (10% of engagement)
7. AI/ML Applications
8. Remote Work & Async Culture
9. Technical Writing

## Your Voice Characteristics

### Tone Profile
- **Confidence Level**: 7/10 - You engage with confident voices but not arrogant ones
- **Humor Style**: Dry wit > sarcasm > absurdism > none > cringe
- **Controversy Tolerance**: Medium - You appreciate challenging takes but not pure dunking
- **Technicality**: Accessible technical - expertise visible but not gatekeeping

### Content Style Preferences
- Format: Threads (3-5 tweets) and thoughtful single tweets
- Evidence: Experience-based > data-based > assertion-based
- Structure: Problem/insight/learning arc
- Personality: Present but professional

### Your Anti-Voice (What You Don't Engage With)
- Hustle culture motivation
- Hype without substance ("This will change everything!")
- Pure negativity without constructive alternative
- Obvious engagement farming
- Content that talks down to readers

## Your Tribe

### Authors Who Shaped Your Taste
[List of 10-15 accounts with engagement stats and what they represent]

### The Voice Archetypes You Love
1. **The Generous Expert**: Makes complex things accessible
2. **The Honest Practitioner**: Shares real learnings, admits failures
3. **The Cultural Critic**: Calls out industry BS with wit

### Your Potential Position
Based on your engagement graph, you'd naturally fit in the intersection of:
- Indie hacker/bootstrapper community
- DX/tooling enthusiasts
- Thoughtful tech culture critics

## Timeline: Your Evolution

### Early Years (2014-2016)
- Heavy JavaScript ecosystem focus
- Consuming more than curating
- Pattern: Following the hype cycle

### Growth Years (2017-2019)
- Developing distinct taste
- Unfollowed noisy accounts
- Pattern: Quality over quantity

### Refinement (2020-2022)
- Very selective engagement
- Deep thread reading
- Pattern: Expertise in curation

### Present (2023-2024)
- Strong opinions formed
- Engagement with niche voices
- Pattern: Ready to contribute

## Sample Voice Outputs

Based on your profile, here's what your voice might sound like:

### On Developer Tooling:
"Hot take: 90% of 'revolutionary' dev tools fail because they're built by
people who think the problem is technology, not workflow. Your CLI doesn't
need to be faster. It needs to not require me to google the flags every time."

### On Tech Culture:
"The 'just ship it' crowd and the 'engineering excellence' crowd are both
right and both wrong. Shipping broken stuff is bad. Not shipping at all is
worse. Wisdom is knowing which phase you're in."

### On Indie Building:
"Three years of following indie hackers has taught me one thing: the people
who make it aren't the ones with the best ideas. They're the ones who can
tolerate two years of being ignored."

## Engagement Insights

### Your Peak Engagement Times
- **Day**: Tuesday-Thursday
- **Time**: 9-11am PST, 4-6pm PST
- **Context**: More engagement during tech conferences/launches

### What Makes You Hit Like
1. Insight I hadn't considered (novelty)
2. Perfect articulation of something I felt (resonance)
3. Useful information I'll reference (utility)
4. Genuinely funny observation (delight)

### Your Engagement Quirks
- You like threads but rarely finish ones >10 tweets
- You bookmark technical content but like cultural content
- You engage more with authors after their 3rd viral tweet (quality filter)

## Suggested Starting Points

Based on your profile, here are high-confidence first contributions:

### Reply Opportunities
- Threads about developer tooling (you have strong opinions here)
- Indie business updates (supportive community, low stakes)
- "What tools do you use?" threads (you're a curated expert)

### Original Post Ideas
- Your favorite underrated dev tools (your bookmarks are full of these)
- Observations about how your company does X differently
- That thing that annoys you about the industry that you've liked 20 tweets about

### Avoid Initially
- Hot takes on current drama (high risk, not your style)
- Abstract philosophical takes (you prefer grounded experience)
- Anything performatively contrarian (not your vibe)
```

### Example Insight Cards

The Voice Profile also generates shareable "insight cards" - bite-sized revelations:

**Card 1: Hidden Obsession**
```
You've liked 127 tweets about error messages and debugging experience.
That's more than your likes about any programming language.
You might be a DX person pretending to be a systems person.
```

**Card 2: The Lurker's Tell**
```
You've engaged with @author's content 34 times over 6 years.
You've never replied to them once.
They have 3,400 followers. They'd probably reply back.
```

**Card 3: Taste Evolution**
```
2018: You liked "Kubernetes will change everything!"
2023: You liked "Kubernetes was a mistake for most teams"
Your BS detector developed nicely.
```

**Card 4: The Voice You Almost Have**
```
You've liked 89 tweets that start with "Unpopular opinion:"
You've never posted an unpopular opinion.
You have opinions. You've just been quiet about them.
```

---

## 5. Privacy Considerations

### Principle: Everything Stays Local

Archive Archaeology operates on a fundamental principle: **your self-discovery stays with you.**

**Technical Implementation:**
- All data processing happens on-device
- Raw engagement data never leaves your machine
- LLM analysis uses local models or anonymous API calls
- Voice profile document stored only in local app storage
- No data shared with servers beyond what Twitter's own export provides

### Handling Embarrassing History

**The Problem:** People's likes from 2014 may not reflect who they are in 2024. Old takes age poorly. Past interests may be embarrassing.

**The Solution: Archaeology Controls**

```
Archaeology Scope Settings:

Time Range:
[x] Last 3 years
[ ] Last 5 years
[ ] Last 10 years
[ ] Complete history

Content Filters:
[x] Skip sensitive topics (politics, controversy)
[x] Exclude specific accounts: [@account1, @account2]
[x] Exclude date ranges: [2020-03-01 to 2020-06-01]

Analysis Exclusions:
[x] Don't analyze sentiment on personal/emotional content
[x] Skip content from accounts that were later suspended
```

### The Embarrassment Protocol

When the system encounters potentially embarrassing patterns:

1. **Flagging**: Sensitive clusters are identified but not prominently featured
2. **Private Reflection**: "We found some engagement patterns you might want to review privately before including in your profile"
3. **Easy Exclusion**: One-click removal of any insight or pattern
4. **No Judgment**: System never moralizes; presents data neutrally

### The "Delete Before Analyzing" Option

Some users may want to clean up their history before archaeology:

```
Pre-Archaeology Cleanup:

Would you like to review your engagement history before analysis?

[Review Oldest Likes] - See likes from 2014-2016
[Review by Topic] - See clusters of engagement by theme
[Review Potentially Sensitive] - AI-flagged content that might be outdated

Note: We don't suggest what to delete. We just help you find things
you might want to reconsider before building your voice profile.
```

### Consent Layers

```
Archaeology Consent:

Level 1: Basic Overview
- Topic clusters only
- No specific tweets or authors analyzed
- Minimal personal insight

Level 2: Standard Analysis (Recommended)
- Full topic and author analysis
- Style and sentiment profiling
- Personalized voice suggestions

Level 3: Deep Archaeology
- Evolution timeline
- Behavioral pattern analysis
- Predictive voice modeling
- Cross-reference with public discourse
```

---

## 6. Implementation Approach

### Data Acquisition Strategy

#### Method 1: Official Twitter/X Archive

**Process:**
1. User requests data download from Twitter Settings
2. Twitter prepares archive (takes 24-48 hours)
3. User downloads ZIP file
4. App ingests and parses archive locally

**Archive Contents:**
- `like.js` - Full history of liked tweets
- `bookmark.js` - All bookmarks (recent API addition)
- `following.js` - Current follows
- `tweet.js` - User's own tweets (empty for lurkers)

**Limitations:**
- Archive preparation takes time (24-48 hours)
- May not include full metadata (engagement counts at time of like)
- Historical follows/unfollows may be incomplete

#### Method 2: API Access (Authenticated)

**Process:**
1. User authenticates with Twitter OAuth
2. App fetches engagement history via API
3. Rate-limited but real-time

**API Endpoints:**
- `GET /2/users/:id/liked_tweets` - User's likes
- `GET /2/users/:id/bookmarks` - User's bookmarks
- `GET /2/users/:id/following` - User's follows

**Limitations:**
- API rate limits (may take hours for 10 years of data)
- API access costs (Twitter API is now paid)
- Limited historical depth on some endpoints

#### Method 3: Hybrid Approach (Recommended)

1. **Initial Load**: Use Twitter archive for complete historical data
2. **Incremental Updates**: Use API for new engagement since archive date
3. **Enrichment**: Use API to fetch additional metadata for archive tweets

### Storage Architecture

```
Local Storage Schema:

engagement_store/
  likes/
    raw/           # Original tweet data
    embeddings/    # Vector representations
    metadata/      # Engagement timestamps, etc.
  bookmarks/
    raw/
    embeddings/
    metadata/
  follows/
    current/
    history/       # If recoverable
  analysis/
    clusters/      # Topic clustering results
    authors/       # Author affinity data
    timeline/      # Evolution analysis
    profile/       # Generated voice profile
```

**Storage Estimates:**
- 5,000 likes: ~50MB raw, ~200MB with embeddings
- 500 bookmarks: ~5MB raw, ~20MB with embeddings
- Analysis artifacts: ~50MB
- **Total**: ~300-500MB for heavy user

### Processing Pipeline

```
Pipeline Stages:

1. INGEST
   ├─ Parse archive/API data
   ├─ Normalize tweet format
   ├─ Fetch missing metadata
   └─ Store in local database

2. EMBED
   ├─ Generate text embeddings (local model or API)
   ├─ Store vectors for similarity search
   └─ Build embedding index

3. CLUSTER
   ├─ Run clustering algorithm
   ├─ Label clusters with LLM
   ├─ Calculate cluster metrics
   └─ Identify outliers/bridges

4. ANALYZE
   ├─ Author affinity scoring
   ├─ Sentiment distribution
   ├─ Style fingerprinting
   ├─ Timeline evolution
   └─ Behavioral patterns

5. SYNTHESIZE
   ├─ Generate voice profile document
   ├─ Create insight cards
   ├─ Build sample voice outputs
   └─ Generate recommendations

6. PRESENT
   ├─ Render profile UI
   ├─ Enable exploration
   ├─ Connect to other features
   └─ Export options
```

### LLM Prompts for Analysis

#### Cluster Labeling Prompt

```
You are analyzing a cluster of tweets that a user has liked over time.
Your job is to give this cluster a name and characterize what draws
this user to this type of content.

Here are 20 representative tweets from this cluster:
{tweets}

Provide:
1. A short name for this cluster (3-5 words)
2. A one-sentence description of the theme
3. A "vibe check" - what does liking this content say about the person?
4. 3-5 key terms or hashtags associated with this cluster

Format as JSON.
```

#### Voice Profile Synthesis Prompt

```
You are creating a voice profile for someone based on their Twitter
engagement history. This person has never posted - they're a lurker -
but their likes and bookmarks reveal deep preferences.

Here is the analysis data:
- Topic clusters: {clusters}
- Top engaged authors: {authors}
- Style preferences: {style}
- Sentiment distribution: {sentiment}
- Evolution over time: {timeline}

Create a Voice Profile that:
1. Identifies their likely "voice archetype"
2. Describes the tone and style that would feel authentic to them
3. Suggests topics they could speak authentically about
4. Provides 3 example tweets/threads in "their voice"
5. Notes what they should probably avoid

Be specific and actionable. This should help a lurker understand
what their voice could sound like and feel confident it's authentic.
```

#### Sample Voice Generation Prompt

```
Based on this voice profile:
{profile_summary}

And these examples of content they've engaged with:
{sample_likes}

Write 3 example tweets in what their authentic voice might sound like:
1. A thread opener about {topic_1}
2. A reply to a post about {topic_2}
3. A standalone observation about {topic_3}

Match the tone, technicality, and style of content they've demonstrated
preference for. Don't make it sound like an AI - make it sound like
a person with this specific taste finally deciding to speak.
```

### Technical Stack Recommendation

```
Recommended Implementation:

Data Layer:
- SQLite for structured data
- Qdrant/ChromaDB for vector storage (local)
- File system for raw archives

Processing:
- Python backend for analysis
- sentence-transformers for embeddings (local)
- HDBSCAN for clustering
- Local LLM (Llama/Mistral) or Claude API for synthesis

Frontend:
- React/Solid for profile visualization
- D3.js for interest maps and evolution timelines
- Markdown rendering for profile document
```

---

## 7. Example User Journey

### The Setup (Day 0)

**Sarah** has had a Twitter account since 2014. She follows 1,247 people - mostly tech folks, indie hackers, and a few comedians. She has never posted. Not once. She's liked 6,341 tweets and bookmarked 418.

She downloads the X engagement app because she keeps telling herself "I should post more" but never does.

### The Discovery (Day 1)

Sarah sees the Archive Archaeology feature on the home screen:

```
┌─────────────────────────────────────────────────────────────┐
│  Archive Archaeology                                         │
│                                                             │
│  You have 10 years of engagement history.                   │
│  6,341 likes. 418 bookmarks. 0 tweets.                      │
│                                                             │
│  Your likes tell a story about who you are.                 │
│  Want to discover your voice?                               │
│                                                             │
│  [Begin Archaeology]                                        │
│                                                             │
│  Takes about 5 minutes. Everything stays on your device.   │
└─────────────────────────────────────────────────────────────┘
```

She clicks "Begin Archaeology" and connects her Twitter archive.

### The Processing (Day 1, 10 minutes later)

The app shows progress with interesting micro-discoveries:

```
Analyzing your history...

[████████████████████░░░░░░░░░░] 68%

While we work, some quick observations:

  Your first like was on March 14, 2014:
  "@pmarca: Software is eating the world, but some
  bites are bigger than others."

  You've liked something from 847 different accounts.
  But 40% of your likes come from just 23 accounts.
  You know your people.

  Your most-liked tweet had 2 likes when you liked it.
  You find gems before they go viral.
```

### The Revelation (Day 1, 15 minutes in)

The analysis completes. Sarah sees her Voice Profile for the first time:

```
Your Voice Profile

┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  You are a "Thoughtful Practitioner"                        │
│                                                             │
│  Based on 10 years of engagement, you value:                │
│  • Substance over hype                                      │
│  • Experience over theory                                   │
│  • Dry wit over loud humor                                  │
│  • Nuance over hot takes                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

She scrolls down to her Interest Map and is genuinely surprised:

```
Your Core Interests:

1. Developer Experience (23%)
   - Error messages, CLIs, documentation, onboarding

2. Indie Hacking (19%)
   - Solo founders, sustainable businesses, pricing

3. Engineering Culture (15%)
   - How teams work, interviewing, career advice
```

*Sarah's internal reaction: "Wait, I always thought I was mainly interested in distributed systems. I talk about wanting to learn more about databases all the time. But my likes say... developer experience? Huh."*

### The Insight Cards (Day 1, 20 minutes in)

She swipes through the insight cards:

**Card: Your Secret Obsession**
```
You've liked 156 tweets about onboarding and documentation.
That's more than any other topic.
You've never told anyone you care about this.
Maybe you should.
```

**Card: Your Favorite Voice**
```
You've engaged with @swyx 89 times over 5 years.
His style: learning in public, generous synthesis, technical but accessible.
Your style probably wants to be like this.
```

**Card: The Take You Almost Took**
```
You bookmarked this tweet in 2019:
"Hot take: Most technical interviews test for trivia, not talent"

23 other tweets in your bookmarks are about interviewing.
You have opinions about this. Strong ones.
```

### The Sample Voices (Day 1, 25 minutes in)

The profile shows what her voice might sound like:

```
If you posted about Developer Experience:

"Hot take: The best documentation isn't comprehensive - it's
discoverable. I don't want to read your 200-page manual. I want
to find the exact answer in 30 seconds. Index your docs like
someone's searching in a panic."

If you replied to an indie hacker update:

"The hardest part isn't building it. It's the 18 months where
you tweet into the void and wonder if you're delusional. You're
not. Keep going."

If you observed tech culture:

"Noticed something: the people with the strongest opinions about
'AI taking coding jobs' are either (a) people who don't code, or
(b) people who write boilerplate all day. The people building
interesting things seem... fine? Curious?"
```

Sarah reads these and thinks: *"...that actually does sound like something I would say. How did it know?"*

### The Confidence Moment (Day 1, 30 minutes in)

At the bottom of her profile, she sees:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  You've been curating for 10 years.                         │
│  You know what's good.                                      │
│  You have opinions.                                         │
│  You just haven't said them out loud yet.                   │
│                                                             │
│  Ready to try?                                              │
│                                                             │
│  [Practice a Reply] [Draft Your First Post] [Explore More] │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

She clicks "Practice a Reply" and is taken to the Reply Gym with personalized suggestions based on her voice profile.

### The First Post (Day 4)

Three days of practice replies later, Sarah feels ready. The app suggests a low-stakes first post based on her profile:

```
Suggested First Post:

Based on your engagement with DX content, here's a natural entry point:

"What's one small DX improvement that made your day significantly better?
I'll start: the editor that finally showed me the type error *where* the
error actually was, not three files away."

This aligns with your voice because:
✓ Asks a question (invites engagement, low commitment)
✓ Developer experience topic (your strongest interest)
✓ Mildly opinionated (you have a take but it's not aggressive)
✓ Personal experience anchor (grounded, not abstract)

[Edit Draft] [Post Now] [Try Different Angle]
```

She edits it slightly, hovers over "Post Now" for thirty seconds, and clicks.

### The Response (Day 4, 2 hours later)

Her first tweet gets 12 likes and 8 replies. The app shows:

```
First Post Reflection

12 likes, 8 replies, 0 negative responses

How does this compare to your expectations?

[ Much worse than I feared ]
[ About what I expected ]
[x] Better than I thought! ]
[ I'm overwhelmed ]

This is exactly what we predicted for your first post.
Your voice found its audience. Want to reply to some of these?
```

Sarah replies to three of the responses. Each reply feels easier than the last.

### The Integration (Week 2)

Two weeks later, Sarah has posted 7 times and replied 34 times. The Voice Consistency Sentinel checks in:

```
Voice Check-In

Your recent engagement matches your voice profile:
✓ Topics: Developer experience, indie building
✓ Tone: Thoughtful, occasionally witty
✓ Style: Balanced between observation and opinion

One observation:
Your replies are getting shorter (avg 45 words → 22 words).
This might be confidence (efficient!) or fatigue (need a break?).

[ I'm finding my groove ]
[ I should slow down ]
[ Tell me more about this pattern ]
```

### Six Months Later

Sarah has 340 followers - not influencer numbers, but people who genuinely engage with her posts about developer experience. She's been invited to write a guest post for a DX newsletter. Someone DMed her asking for career advice.

She opens Archive Archaeology again, just to compare:

```
Your Voice Profile Evolution

6 months ago: 0 posts, voice discovered through likes
Today: 47 posts, voice actualized through contribution

Your predicted voice vs. actual voice: 87% alignment

You became who you already were.
```

---

## The Killer Feature Thesis

Archive Archaeology isn't just a feature - it's **validation**.

For 10 years, lurkers have been told (by themselves, by Twitter's prompts, by culture) that they're not participating. They're passive. They're just consuming.

Archive Archaeology reframes this:
- **You were curating** - building expertise in what matters
- **You were learning** - absorbing the best from thousands of voices
- **You were developing taste** - filtering signal from noise
- **You were finding your voice** - you just hadn't spoken it yet

The killer insight: **You're not becoming someone new. You're finally expressing who you've always been.**

Every lurker has the same fear: "I have nothing valuable to say."

Archive Archaeology's response: "Here are 6,341 moments where you decided something was valuable. Here's the pattern. Here's your voice. Now say it."

That's the killer feature.

---

## Appendix: Technical Specifications

### Data Model

```typescript
interface EngagementHistory {
  likes: Like[];
  bookmarks: Bookmark[];
  follows: Follow[];
  retweets: Retweet[];
}

interface Like {
  tweetId: string;
  tweetText: string;
  tweetAuthor: Author;
  likedAt: Date;
  tweetCreatedAt: Date;
  engagementAtLike?: EngagementMetrics;
  embedding?: number[];
}

interface VoiceProfile {
  archetype: string;
  summary: string;
  topicClusters: TopicCluster[];
  authorAffinities: AuthorAffinity[];
  styleFingerprint: StyleFingerprint;
  sentimentProfile: SentimentProfile;
  evolutionTimeline: EvolutionPeriod[];
  insightCards: InsightCard[];
  sampleVoices: SampleVoice[];
  recommendations: Recommendation[];
}

interface TopicCluster {
  id: string;
  name: string;
  description: string;
  vibeCheck: string;
  percentageOfEngagement: number;
  keyTerms: string[];
  representativeTweets: Like[];
  evolution: TrendDirection;
}
```

### Performance Targets

| Metric | Target |
|--------|--------|
| Archive ingestion (10K likes) | < 2 minutes |
| Embedding generation | < 5 minutes |
| Clustering analysis | < 1 minute |
| Profile generation | < 2 minutes |
| **Total time to insight** | **< 10 minutes** |

### Privacy Checklist

- [ ] All processing local by default
- [ ] No engagement data sent to external servers
- [ ] LLM calls use anonymous prompts (no PII)
- [ ] User can export/delete all analysis data
- [ ] Sensitive content filters available
- [ ] Time-range controls for analysis scope
- [ ] Explicit consent for each analysis depth level
