# Feed Monitoring and Content Curation Patterns

## Executive Summary

This document outlines design patterns for efficiently monitoring 1000+ followed accounts on Twitter/X and surfacing the most relevant and engaging content. The challenge involves handling high-volume data streams, implementing intelligent ranking algorithms, organizing accounts into meaningful categories, and providing users with actionable notifications without overwhelming them.

Key strategies include:
- **Streaming-first architecture** with event-driven processing for real-time updates
- **Multi-signal ranking algorithms** combining engagement metrics, recency, user interest modeling, and content quality
- **Hierarchical categorization** using Twitter Lists, AI-powered topic detection, and manual priority tiers
- **Smart notification filtering** with configurable thresholds and time-based batching
- **Thread reconstruction** using conversation_id traversal for complete context
- **Intelligent bookmark systems** with read-it-later queues and engagement scheduling

---

## 1. Feed Aggregation Strategies

### 1.1 Architecture Patterns for High-Volume Feeds

#### Streaming vs Polling Architecture

For monitoring 1000+ accounts, a hybrid approach works best:

```
+------------------+     +------------------+     +------------------+
|  Twitter API     |     |  Message Queue   |     |  Processing      |
|  Filtered Stream |---->|  (Kafka/Redis)   |---->|  Workers         |
+------------------+     +------------------+     +------------------+
                                                         |
                                                         v
                         +------------------+     +------------------+
                         |  User Feed       |<----|  Ranking         |
                         |  Database        |     |  Service         |
                         +------------------+     +------------------+
```

**Streaming (Primary)**
- Use Twitter's Filtered Stream API for real-time tweet delivery
- Filter by user IDs of followed accounts
- Low latency, efficient for high-volume monitoring
- Ideal for time-sensitive content detection

**Polling (Supplemental)**
- REST API for gap-filling and historical data
- Implement exponential backoff for rate limit management
- Query less frequently for accounts with low activity

#### Message Queue Design

```typescript
interface TweetEvent {
  tweetId: string;
  authorId: string;
  timestamp: Date;
  content: string;
  engagementMetrics: {
    likes: number;
    retweets: number;
    replies: number;
    quotes: number;
  };
  mediaAttachments: MediaItem[];
  conversationId: string;
  inReplyToId?: string;
  rawPayload: TwitterAPIResponse;
}
```

Use Apache Kafka or Redis Streams for:
- Durable message persistence
- Replay capability for reprocessing
- Partition by user ID for parallel processing
- Dead-letter queues for failed processing

### 1.2 Rate Limit Management

Twitter API enforces strict rate limits. Best practices:

| Endpoint | Limit | Strategy |
|----------|-------|----------|
| Filtered Stream | Continuous | Primary method, one connection |
| User Timeline | 900/15min | Batch requests, cache responses |
| Search/Recent | 450/15min | Use for gap-filling only |

**Implementation Strategies:**
- Monitor `x-rate-limit-remaining` headers dynamically
- Implement token bucket algorithm for request scheduling
- Cache API responses locally (15-minute TTL minimum)
- Use exponential backoff on 429 errors: `delay = min(baseDelay * 2^attempt, maxDelay)`

### 1.3 Data Deduplication

```typescript
class TweetDeduplicator {
  private seenTweets: BloomFilter;
  private recentWindow: LRUCache<string, boolean>;

  isDuplicate(tweetId: string): boolean {
    // Fast bloom filter check
    if (this.seenTweets.mightContain(tweetId)) {
      // Confirm with LRU cache for recent items
      return this.recentWindow.has(tweetId);
    }
    return false;
  }

  markSeen(tweetId: string): void {
    this.seenTweets.add(tweetId);
    this.recentWindow.set(tweetId, true);
  }
}
```

---

## 2. Content Ranking and Filtering Algorithms

### 2.1 Multi-Signal Ranking Model

Modern content ranking combines multiple signal types:

```typescript
interface RankingSignals {
  // Engagement signals
  engagement: {
    likes: number;
    retweets: number;
    replies: number;
    quotes: number;
    bookmarks: number;
    engagementRate: number; // (likes + retweets + replies) / impressions
  };

  // Recency signals
  temporal: {
    ageMinutes: number;
    velocityScore: number; // engagement growth rate
    isBreaking: boolean;
  };

  // Author signals
  author: {
    authorTier: 'vip' | 'important' | 'normal' | 'low';
    historicalEngagementRate: number;
    postFrequency: number;
    userInteractionHistory: number; // how often user engages with this author
  };

  // Content signals
  content: {
    topicRelevance: number; // 0-1 based on user interests
    hasMedia: boolean;
    isThread: boolean;
    sentimentScore: number;
    contentQualityScore: number;
  };

  // Social signals
  social: {
    sharedByFollowed: boolean;
    mutualEngagement: number; // friends who engaged
    isConversation: boolean;
  };
}
```

### 2.2 Scoring Algorithm

```typescript
function calculateTweetScore(signals: RankingSignals): number {
  const weights = {
    engagement: 0.25,
    recency: 0.20,
    authorImportance: 0.20,
    topicRelevance: 0.20,
    socialProof: 0.15
  };

  // Engagement score (log-scaled to prevent viral tweets from dominating)
  const engagementScore = Math.log10(
    signals.engagement.likes * 1 +
    signals.engagement.retweets * 2 +
    signals.engagement.replies * 3 +
    signals.engagement.quotes * 2.5 +
    1 // prevent log(0)
  ) / 6; // normalize to 0-1 range

  // Recency decay (half-life of 6 hours)
  const recencyScore = Math.exp(-0.693 * signals.temporal.ageMinutes / 360);

  // Author tier scoring
  const authorTierScores = { vip: 1.0, important: 0.7, normal: 0.4, low: 0.2 };
  const authorScore = (
    authorTierScores[signals.author.authorTier] * 0.4 +
    signals.author.userInteractionHistory * 0.6
  );

  // Topic relevance from user interest model
  const topicScore = signals.content.topicRelevance;

  // Social proof
  const socialScore = (
    (signals.social.sharedByFollowed ? 0.5 : 0) +
    Math.min(signals.social.mutualEngagement / 5, 0.5)
  );

  // Weighted sum
  return (
    engagementScore * weights.engagement +
    recencyScore * weights.recency +
    authorScore * weights.authorImportance +
    topicScore * weights.topicRelevance +
    socialScore * weights.socialProof
  );
}
```

### 2.3 TF-IDF for Topic Relevance

Use TF-IDF to match tweet content against user interest profiles:

```typescript
class UserInterestModel {
  private termFrequencies: Map<string, number> = new Map();
  private documentCount: number = 0;

  // Update model based on user engagement
  recordEngagement(tweetText: string, engagementWeight: number): void {
    const terms = this.tokenize(tweetText);
    terms.forEach(term => {
      const current = this.termFrequencies.get(term) || 0;
      this.termFrequencies.set(term, current + engagementWeight);
    });
    this.documentCount++;
  }

  // Calculate relevance score for new content
  calculateRelevance(tweetText: string): number {
    const terms = this.tokenize(tweetText);
    let score = 0;

    terms.forEach(term => {
      const tf = this.termFrequencies.get(term) || 0;
      const idf = Math.log(this.documentCount / (tf + 1));
      score += tf * idf;
    });

    return this.normalize(score);
  }

  private tokenize(text: string): string[] {
    return text.toLowerCase()
      .replace(/[^\w\s#@]/g, '')
      .split(/\s+/)
      .filter(t => t.length > 2);
  }
}
```

### 2.4 Velocity-Based Trending Detection

```typescript
interface TweetVelocity {
  tweetId: string;
  measurements: Array<{
    timestamp: Date;
    engagementTotal: number;
  }>;
}

function calculateVelocityScore(velocity: TweetVelocity): number {
  if (velocity.measurements.length < 2) return 0;

  const recent = velocity.measurements.slice(-3);
  const rates: number[] = [];

  for (let i = 1; i < recent.length; i++) {
    const timeDelta = (recent[i].timestamp.getTime() - recent[i-1].timestamp.getTime()) / 60000;
    const engagementDelta = recent[i].engagementTotal - recent[i-1].engagementTotal;
    rates.push(engagementDelta / timeDelta);
  }

  // Acceleration: is the rate increasing?
  const avgRate = rates.reduce((a, b) => a + b, 0) / rates.length;
  const isAccelerating = rates.length > 1 && rates[rates.length - 1] > rates[0];

  return avgRate * (isAccelerating ? 1.5 : 1);
}
```

---

## 3. Categorization Approaches

### 3.1 Twitter Lists for Topic Organization

Twitter Lists are the native mechanism for categorizing followed accounts:

```typescript
interface AccountCategory {
  id: string;
  name: string;
  listId?: string; // Twitter List ID if synced
  type: 'topic' | 'priority' | 'relationship' | 'custom';
  accounts: string[]; // user IDs
  color: string;
  notificationLevel: 'all' | 'important' | 'none';
}

const suggestedCategories: AccountCategory[] = [
  // Priority tiers
  { name: 'VIP', type: 'priority', notificationLevel: 'all' },
  { name: 'Important', type: 'priority', notificationLevel: 'important' },
  { name: 'Normal', type: 'priority', notificationLevel: 'none' },

  // Topic categories
  { name: 'Tech News', type: 'topic', notificationLevel: 'important' },
  { name: 'Crypto/Web3', type: 'topic', notificationLevel: 'important' },
  { name: 'Industry Experts', type: 'topic', notificationLevel: 'important' },
  { name: 'Entertainment', type: 'topic', notificationLevel: 'none' },

  // Relationship categories
  { name: 'Friends', type: 'relationship', notificationLevel: 'all' },
  { name: 'Colleagues', type: 'relationship', notificationLevel: 'important' },
];
```

### 3.2 Auto-Categorization Using ML

```typescript
class AccountCategorizer {
  private topicModel: TopicClassifier;

  async categorizeAccount(userId: string): Promise<string[]> {
    // Fetch recent tweets from account
    const recentTweets = await this.fetchRecentTweets(userId, 100);

    // Extract features
    const features = {
      bioKeywords: this.extractBioKeywords(userId),
      tweetTopics: this.topicModel.classify(recentTweets),
      postingPatterns: this.analyzePostingPatterns(recentTweets),
      engagementProfile: this.analyzeEngagement(recentTweets),
    };

    // Suggest categories
    const categories: string[] = [];

    if (features.tweetTopics.includes('technology')) categories.push('Tech');
    if (features.tweetTopics.includes('finance')) categories.push('Finance');
    if (features.postingPatterns.isNewsSource) categories.push('News');
    if (features.engagementProfile.averageLikes > 1000) categories.push('Influencer');

    return categories;
  }
}
```

### 3.3 Priority Scoring for Accounts

```typescript
function calculateAccountPriority(account: AccountProfile, userHistory: UserHistory): number {
  const signals = {
    // How often user engages with this account
    engagementFrequency: userHistory.getEngagementCount(account.id) /
                         userHistory.getTotalEngagements(),

    // How often this account posts content user engages with
    contentRelevance: userHistory.getRelevanceScore(account.id),

    // Account's overall influence
    influenceScore: Math.log10(account.followers + 1) / 10,

    // Recency of last interaction
    lastInteractionRecency: Math.exp(-0.693 *
      daysSince(userHistory.getLastInteraction(account.id)) / 30),

    // Manual boost from user
    manualBoost: userHistory.getManualPriorityBoost(account.id),
  };

  return (
    signals.engagementFrequency * 0.30 +
    signals.contentRelevance * 0.30 +
    signals.influenceScore * 0.10 +
    signals.lastInteractionRecency * 0.15 +
    signals.manualBoost * 0.15
  );
}
```

---

## 4. Notification Strategies

### 4.1 Notification Tiers

```typescript
enum NotificationTier {
  IMMEDIATE = 'immediate',    // Push notification within seconds
  BATCHED_HOURLY = 'hourly',  // Digest every hour
  BATCHED_DAILY = 'daily',    // Daily summary
  SILENT = 'silent',          // No notification, just in feed
}

interface NotificationRule {
  condition: (tweet: Tweet, author: Account, context: UserContext) => boolean;
  tier: NotificationTier;
  priority: number;
}

const notificationRules: NotificationRule[] = [
  // VIP accounts - always notify
  {
    condition: (tweet, author, ctx) => ctx.isVIP(author.id),
    tier: NotificationTier.IMMEDIATE,
    priority: 100,
  },

  // High-velocity tweets from important accounts
  {
    condition: (tweet, author, ctx) =>
      ctx.isImportant(author.id) && tweet.velocityScore > 0.8,
    tier: NotificationTier.IMMEDIATE,
    priority: 90,
  },

  // Mentions of user
  {
    condition: (tweet, author, ctx) =>
      tweet.mentions.includes(ctx.userId),
    tier: NotificationTier.IMMEDIATE,
    priority: 95,
  },

  // Topics user is tracking
  {
    condition: (tweet, author, ctx) =>
      ctx.trackedTopics.some(t => tweet.topics.includes(t)),
    tier: NotificationTier.BATCHED_HOURLY,
    priority: 70,
  },

  // Breaking news detection
  {
    condition: (tweet, author, ctx) =>
      tweet.isBreakingNews && ctx.categories.get(author.id)?.includes('News'),
    tier: NotificationTier.IMMEDIATE,
    priority: 85,
  },

  // Default for followed accounts
  {
    condition: () => true,
    tier: NotificationTier.SILENT,
    priority: 0,
  },
];
```

### 4.2 Smart Batching System

```typescript
class NotificationBatcher {
  private queues: Map<NotificationTier, Tweet[]> = new Map();
  private lastDelivery: Map<NotificationTier, Date> = new Map();

  async queueNotification(tweet: Tweet, tier: NotificationTier): Promise<void> {
    if (tier === NotificationTier.IMMEDIATE) {
      await this.sendImmediately(tweet);
      return;
    }

    const queue = this.queues.get(tier) || [];
    queue.push(tweet);
    this.queues.set(tier, queue);

    // Check if batch should be sent
    if (this.shouldFlush(tier)) {
      await this.flushQueue(tier);
    }
  }

  private shouldFlush(tier: NotificationTier): boolean {
    const queue = this.queues.get(tier) || [];
    const lastDelivery = this.lastDelivery.get(tier);

    const intervals = {
      [NotificationTier.BATCHED_HOURLY]: 60 * 60 * 1000,
      [NotificationTier.BATCHED_DAILY]: 24 * 60 * 60 * 1000,
    };

    const maxBatchSize = 10;
    const interval = intervals[tier];

    // Flush if batch is full or interval has passed
    return queue.length >= maxBatchSize ||
           (lastDelivery && Date.now() - lastDelivery.getTime() > interval);
  }

  private async flushQueue(tier: NotificationTier): Promise<void> {
    const queue = this.queues.get(tier) || [];
    if (queue.length === 0) return;

    // Rank and select top items for digest
    const ranked = queue
      .sort((a, b) => b.score - a.score)
      .slice(0, 5);

    await this.sendDigest(ranked, tier);

    this.queues.set(tier, []);
    this.lastDelivery.set(tier, new Date());
  }
}
```

### 4.3 Quiet Hours and Focus Mode

```typescript
interface NotificationPreferences {
  quietHours: {
    enabled: boolean;
    start: string; // "22:00"
    end: string;   // "07:00"
    timezone: string;
  };

  focusMode: {
    enabled: boolean;
    allowedTiers: NotificationTier[];
    allowedAuthors: string[]; // VIP override list
  };

  dailyDigestTime: string; // "08:00"
}
```

---

## 5. Thread Reconstruction

### 5.1 Conversation ID Traversal

Twitter assigns a `conversation_id` to all tweets in a thread, matching the original tweet's ID:

```typescript
interface ConversationNode {
  tweet: Tweet;
  children: ConversationNode[];
  parent?: ConversationNode;
}

class ThreadReconstructor {
  private tweetCache: Map<string, Tweet> = new Map();

  async reconstructThread(tweetId: string): Promise<ConversationNode> {
    const tweet = await this.fetchTweet(tweetId);
    const conversationId = tweet.conversationId;

    // Fetch all tweets in conversation
    const conversationTweets = await this.fetchConversation(conversationId);

    // Build tree structure
    return this.buildTree(conversationTweets, conversationId);
  }

  private buildTree(tweets: Tweet[], rootId: string): ConversationNode {
    const nodeMap = new Map<string, ConversationNode>();

    // Create nodes
    tweets.forEach(tweet => {
      nodeMap.set(tweet.id, { tweet, children: [] });
    });

    // Link parents and children
    let root: ConversationNode | undefined;

    tweets.forEach(tweet => {
      const node = nodeMap.get(tweet.id)!;

      if (tweet.id === rootId) {
        root = node;
      } else if (tweet.inReplyToId) {
        const parent = nodeMap.get(tweet.inReplyToId);
        if (parent) {
          parent.children.push(node);
          node.parent = parent;
        }
      }
    });

    // Sort children by engagement or chronological
    this.sortChildren(root!);

    return root!;
  }

  private sortChildren(node: ConversationNode): void {
    node.children.sort((a, b) => {
      // Author replies first, then by engagement
      const aIsAuthor = a.tweet.authorId === node.tweet.authorId;
      const bIsAuthor = b.tweet.authorId === node.tweet.authorId;

      if (aIsAuthor && !bIsAuthor) return -1;
      if (bIsAuthor && !aIsAuthor) return 1;

      return b.tweet.engagementScore - a.tweet.engagementScore;
    });

    node.children.forEach(child => this.sortChildren(child));
  }
}
```

### 5.2 Thread Detection Heuristics

```typescript
function detectThreadStart(tweet: Tweet): boolean {
  // Check for common thread indicators
  const threadPatterns = [
    /^(thread|1\/|1\)|🧵)/i,
    /\(thread\)/i,
    /a thread/i,
  ];

  return threadPatterns.some(pattern => pattern.test(tweet.text));
}

function estimateThreadLength(startTweet: Tweet, author: Account): number {
  // Use author's historical thread patterns
  const avgThreadLength = author.metrics.averageThreadLength || 5;

  // Check for explicit length indicators
  const lengthMatch = startTweet.text.match(/(\d+)\s*(tweets?|parts?)/i);
  if (lengthMatch) {
    return parseInt(lengthMatch[1]);
  }

  return avgThreadLength;
}
```

---

## 6. Bookmark and Save Patterns

### 6.1 Save Queue Data Model

```typescript
interface SavedItem {
  id: string;
  tweetId: string;
  savedAt: Date;

  // Classification
  reason: 'bookmark' | 'reply_later' | 'share_later' | 'research';
  tags: string[];

  // Scheduling
  scheduledAction?: {
    type: 'reply' | 'retweet' | 'quote' | 'read';
    scheduledFor?: Date;
    reminderSent: boolean;
  };

  // State tracking
  status: 'pending' | 'in_progress' | 'completed' | 'archived';

  // Context preservation
  snapshot: {
    tweetText: string;
    authorHandle: string;
    engagementAtSave: EngagementMetrics;
    threadContext?: string[]; // parent tweets if it's a reply
  };

  // User notes
  notes?: string;
}
```

### 6.2 Smart Save Suggestions

```typescript
class SaveSuggester {
  async suggestSave(tweet: Tweet, context: UserContext): Promise<SaveSuggestion | null> {
    const signals = {
      // High engagement tweet user might want to reference
      isHighEngagement: tweet.engagementScore > 0.8,

      // Contains actionable content
      hasLink: tweet.urls.length > 0,
      hasThread: tweet.isThread,

      // Relevant to user's interests
      topicMatch: context.topInterests
        .some(interest => tweet.topics.includes(interest)),

      // Time-sensitive content
      isTimeSensitive: this.detectTimeSensitivity(tweet),

      // User has interacted but not saved
      hasInteracted: context.hasLiked(tweet.id) || context.hasRetweeted(tweet.id),
    };

    if (signals.isHighEngagement && signals.topicMatch && !context.hasSaved(tweet.id)) {
      return {
        tweet,
        reason: 'High-engagement content matching your interests',
        suggestedTags: tweet.topics,
        priority: 'medium',
      };
    }

    return null;
  }

  private detectTimeSensitivity(tweet: Tweet): boolean {
    const timePatterns = [
      /limited time/i,
      /ends (today|tomorrow|soon)/i,
      /deadline/i,
      /last chance/i,
      /happening now/i,
    ];

    return timePatterns.some(p => p.test(tweet.text));
  }
}
```

### 6.3 Read Later Queue Management

```typescript
class ReadLaterQueue {
  private items: SavedItem[] = [];

  getNextToRead(context: ReadingContext): SavedItem | null {
    const availableTime = context.estimatedReadingTimeMinutes;

    // Filter by reading time and priority
    const candidates = this.items
      .filter(item => item.status === 'pending')
      .map(item => ({
        item,
        score: this.calculateReadingPriority(item, context),
        estimatedTime: this.estimateReadingTime(item),
      }))
      .filter(c => c.estimatedTime <= availableTime)
      .sort((a, b) => b.score - a.score);

    return candidates[0]?.item || null;
  }

  private calculateReadingPriority(item: SavedItem, context: ReadingContext): number {
    const ageInDays = (Date.now() - item.savedAt.getTime()) / (1000 * 60 * 60 * 24);

    // Urgency increases with age
    const ageScore = Math.min(ageInDays / 7, 1);

    // Match current mood/interest
    const topicMatch = context.currentInterests
      .filter(i => item.tags.includes(i)).length / context.currentInterests.length;

    // Scheduled items get priority
    const scheduledBoost = item.scheduledAction?.scheduledFor &&
      item.scheduledAction.scheduledFor <= new Date() ? 0.3 : 0;

    return ageScore * 0.3 + topicMatch * 0.5 + scheduledBoost + 0.2;
  }
}
```

---

## 7. Analytics on Engagement Patterns

### 7.1 Personal Engagement Metrics

```typescript
interface PersonalAnalytics {
  // Posting patterns
  posting: {
    tweetsPerDay: number;
    avgEngagementRate: number;
    bestPostingTimes: Array<{ hour: number; dayOfWeek: number; score: number }>;
    topPerformingContentTypes: string[];
  };

  // Consumption patterns
  consumption: {
    avgDailyTimeSpent: number;
    peakUsageHours: number[];
    contentTypeDistribution: Map<string, number>;
    topEngagedAuthors: Array<{ authorId: string; engagementCount: number }>;
  };

  // Engagement patterns
  engagement: {
    likesGiven: number;
    retweetsGiven: number;
    repliesGiven: number;
    avgResponseTime: number; // time to engage after seeing
    engagementByTopic: Map<string, number>;
    engagementByTimeOfDay: Map<number, number>;
  };

  // Network analysis
  network: {
    mutualFollowers: number;
    engagementReciprocity: number; // ratio of given to received
    topCollaborators: string[];
    communityMembership: string[]; // detected communities
  };
}
```

### 7.2 Tracking Implementation

```typescript
class EngagementTracker {
  private events: EngagementEvent[] = [];

  recordEngagement(event: EngagementEvent): void {
    this.events.push({
      ...event,
      timestamp: new Date(),
      sessionId: this.getCurrentSession(),
    });
  }

  generateInsights(timeRange: DateRange): PersonalAnalytics {
    const relevantEvents = this.events.filter(
      e => e.timestamp >= timeRange.start && e.timestamp <= timeRange.end
    );

    return {
      posting: this.analyzePosting(relevantEvents),
      consumption: this.analyzeConsumption(relevantEvents),
      engagement: this.analyzeEngagement(relevantEvents),
      network: this.analyzeNetwork(relevantEvents),
    };
  }

  private analyzeEngagement(events: EngagementEvent[]): PersonalAnalytics['engagement'] {
    const engagementEvents = events.filter(e =>
      ['like', 'retweet', 'reply', 'quote'].includes(e.type)
    );

    // Group by hour
    const byHour = new Map<number, number>();
    engagementEvents.forEach(e => {
      const hour = e.timestamp.getHours();
      byHour.set(hour, (byHour.get(hour) || 0) + 1);
    });

    // Group by topic
    const byTopic = new Map<string, number>();
    engagementEvents.forEach(e => {
      e.tweetTopics?.forEach(topic => {
        byTopic.set(topic, (byTopic.get(topic) || 0) + 1);
      });
    });

    return {
      likesGiven: engagementEvents.filter(e => e.type === 'like').length,
      retweetsGiven: engagementEvents.filter(e => e.type === 'retweet').length,
      repliesGiven: engagementEvents.filter(e => e.type === 'reply').length,
      avgResponseTime: this.calculateAvgResponseTime(engagementEvents),
      engagementByTopic: byTopic,
      engagementByTimeOfDay: byHour,
    };
  }
}
```

### 7.3 Recommendations Engine

```typescript
class EngagementRecommender {
  generateRecommendations(analytics: PersonalAnalytics): Recommendation[] {
    const recommendations: Recommendation[] = [];

    // Optimal posting time
    const bestTime = analytics.posting.bestPostingTimes[0];
    recommendations.push({
      type: 'posting_time',
      title: 'Optimal Posting Time',
      description: `Your content performs best on ${dayNames[bestTime.dayOfWeek]} at ${bestTime.hour}:00`,
      actionable: true,
    });

    // Underengaged valuable accounts
    const topAuthors = analytics.consumption.topEngagedAuthors.slice(0, 5);
    const followedNotEngaged = this.findUnderengagedFollows(topAuthors);
    if (followedNotEngaged.length > 0) {
      recommendations.push({
        type: 'engagement_opportunity',
        title: 'Reconnect with Valuable Accounts',
        description: `You haven't engaged with ${followedNotEngaged.length} accounts that post content you typically enjoy`,
        accounts: followedNotEngaged,
        actionable: true,
      });
    }

    // Topic diversification
    const topTopics = Array.from(analytics.engagement.engagementByTopic.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([topic]) => topic);

    if (topTopics.length < 3) {
      recommendations.push({
        type: 'diversification',
        title: 'Explore New Topics',
        description: 'Your engagement is concentrated in few topics. Consider exploring related areas.',
        suggestedTopics: this.suggestRelatedTopics(topTopics),
        actionable: true,
      });
    }

    return recommendations;
  }
}
```

---

## 8. Data Model Suggestions

### 8.1 Core Schema

```sql
-- Users and follows
CREATE TABLE followed_accounts (
  id UUID PRIMARY KEY,
  twitter_user_id VARCHAR(255) UNIQUE NOT NULL,
  handle VARCHAR(255) NOT NULL,
  display_name VARCHAR(255),
  bio TEXT,
  follower_count INTEGER,
  following_count INTEGER,

  -- Our categorization
  priority_tier VARCHAR(20) DEFAULT 'normal',
  categories TEXT[], -- array of category names
  custom_tags TEXT[],

  -- Computed metrics
  relevance_score FLOAT DEFAULT 0.5,
  avg_engagement_rate FLOAT,
  post_frequency FLOAT, -- posts per day
  last_tweet_at TIMESTAMP,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Cached tweets
CREATE TABLE tweets (
  id UUID PRIMARY KEY,
  twitter_tweet_id VARCHAR(255) UNIQUE NOT NULL,
  author_id UUID REFERENCES followed_accounts(id),

  -- Content
  text TEXT NOT NULL,
  media_urls TEXT[],
  urls TEXT[],
  hashtags TEXT[],
  mentions TEXT[],

  -- Thread info
  conversation_id VARCHAR(255),
  in_reply_to_id VARCHAR(255),
  is_thread_start BOOLEAN DEFAULT FALSE,

  -- Engagement (updated periodically)
  likes INTEGER DEFAULT 0,
  retweets INTEGER DEFAULT 0,
  replies INTEGER DEFAULT 0,
  quotes INTEGER DEFAULT 0,

  -- Computed scores
  engagement_score FLOAT,
  relevance_score FLOAT,
  velocity_score FLOAT,

  -- Classification
  detected_topics TEXT[],
  sentiment_score FLOAT,
  is_breaking_news BOOLEAN DEFAULT FALSE,

  -- Timestamps
  twitter_created_at TIMESTAMP NOT NULL,
  fetched_at TIMESTAMP DEFAULT NOW(),
  last_engagement_update TIMESTAMP
);

-- User interactions
CREATE TABLE user_interactions (
  id UUID PRIMARY KEY,
  tweet_id UUID REFERENCES tweets(id),

  interaction_type VARCHAR(50) NOT NULL, -- 'view', 'like', 'retweet', 'reply', 'quote', 'bookmark'

  -- Timing
  interacted_at TIMESTAMP DEFAULT NOW(),
  time_to_interact INTEGER, -- seconds from tweet appearance to interaction

  -- Context
  session_id UUID,
  source VARCHAR(50), -- 'feed', 'notification', 'search', 'profile'

  INDEX idx_interactions_type_time (interaction_type, interacted_at)
);

-- Saved items / bookmarks
CREATE TABLE saved_items (
  id UUID PRIMARY KEY,
  tweet_id UUID REFERENCES tweets(id),

  reason VARCHAR(50) NOT NULL,
  tags TEXT[],
  notes TEXT,

  -- Scheduling
  scheduled_action VARCHAR(50),
  scheduled_for TIMESTAMP,
  reminder_sent BOOLEAN DEFAULT FALSE,

  -- Status
  status VARCHAR(20) DEFAULT 'pending',
  completed_at TIMESTAMP,

  -- Snapshot for offline access
  snapshot JSONB NOT NULL,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Notification history
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  tweet_id UUID REFERENCES tweets(id),

  notification_tier VARCHAR(20) NOT NULL,
  rule_matched VARCHAR(100),

  -- Delivery status
  delivered_at TIMESTAMP,
  delivery_method VARCHAR(50), -- 'push', 'digest', 'in_app'

  -- User response
  opened_at TIMESTAMP,
  engaged_at TIMESTAMP,
  dismissed_at TIMESTAMP,

  created_at TIMESTAMP DEFAULT NOW()
);

-- Categories/Lists
CREATE TABLE categories (
  id UUID PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(50) NOT NULL,
  twitter_list_id VARCHAR(255),

  color VARCHAR(7),
  notification_level VARCHAR(20) DEFAULT 'none',

  is_default BOOLEAN DEFAULT FALSE,
  display_order INTEGER,

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE category_memberships (
  category_id UUID REFERENCES categories(id),
  account_id UUID REFERENCES followed_accounts(id),

  added_at TIMESTAMP DEFAULT NOW(),
  added_by VARCHAR(50), -- 'manual', 'auto', 'suggestion'

  PRIMARY KEY (category_id, account_id)
);
```

### 8.2 Indexes for Performance

```sql
-- Fast feed queries
CREATE INDEX idx_tweets_created_score
  ON tweets (twitter_created_at DESC, engagement_score DESC);

CREATE INDEX idx_tweets_author_created
  ON tweets (author_id, twitter_created_at DESC);

CREATE INDEX idx_tweets_conversation
  ON tweets (conversation_id)
  WHERE conversation_id IS NOT NULL;

-- Notification processing
CREATE INDEX idx_notifications_pending
  ON notifications (created_at)
  WHERE delivered_at IS NULL;

-- Saved items queue
CREATE INDEX idx_saved_pending
  ON saved_items (status, scheduled_for)
  WHERE status = 'pending';

-- Analytics queries
CREATE INDEX idx_interactions_analytics
  ON user_interactions (interaction_type, interacted_at);
```

---

## 9. UX Considerations

### 9.1 Feed Presentation Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Ranked** | ML-scored relevance | Default browsing |
| **Chronological** | Time-ordered | Catching up on all content |
| **Category** | Filtered by list/topic | Focused reading |
| **Trending** | Velocity-sorted | Discovery |
| **Bookmarked** | Save queue | Task-oriented engagement |

### 9.2 Progressive Loading Pattern

```typescript
interface FeedState {
  items: Tweet[];
  cursor: string | null;
  hasMore: boolean;
  loadingState: 'idle' | 'loading' | 'error';
}

// Cursor-based pagination with prefetching
class FeedPaginator {
  private prefetchThreshold = 5; // items from bottom
  private pageSize = 20;

  async loadNext(state: FeedState): Promise<FeedState> {
    if (!state.hasMore || state.loadingState === 'loading') {
      return state;
    }

    const response = await this.api.getFeed({
      cursor: state.cursor,
      limit: this.pageSize,
    });

    return {
      items: [...state.items, ...response.tweets],
      cursor: response.nextCursor,
      hasMore: response.hasMore,
      loadingState: 'idle',
    };
  }

  shouldPrefetch(state: FeedState, visibleIndex: number): boolean {
    return state.items.length - visibleIndex <= this.prefetchThreshold &&
           state.hasMore &&
           state.loadingState === 'idle';
  }
}
```

### 9.3 Notification UX

```typescript
interface NotificationDisplay {
  // Immediate notifications
  immediate: {
    showBadge: boolean;
    playSound: boolean;
    vibrate: boolean;
    showPreview: boolean;
  };

  // Digest notifications
  digest: {
    maxItems: number;
    groupBy: 'author' | 'topic' | 'none';
    showThumbnails: boolean;
    expandable: boolean;
  };

  // In-app indicators
  inApp: {
    showUnreadCount: boolean;
    highlightNew: boolean;
    separatorForNew: boolean;
  };
}
```

### 9.4 Offline and Performance Considerations

- Cache last 100 tweets per category for instant loading
- Prefetch thread context for tweets likely to be tapped
- Store engagement snapshots with bookmarks for offline reference
- Use skeleton loaders for perceived performance
- Implement optimistic updates for user actions

---

## 10. Examples from Existing Tools

### 10.1 Feedly AI (Leo)

Feedly's approach to content curation is highly relevant:
- **Mute Filters**: Remove mentions of specific keywords permanently
- **Topic AI Model**: Prioritize specific keywords and topics
- **Like-Board Skill**: Train the AI by example - curate a board of topics and let the AI learn your preferences
- **Business Event Models**: Track specific event types like product launches, funding events

**Applicable patterns:**
- Train ranking model on explicit user feedback (likes, saves)
- Allow negative signals (mute) not just positive
- Provide topic-level controls, not just account-level

### 10.2 Pocket/Instapaper

Read-it-later apps offer valuable patterns:
- **One-click save** with browser extension
- **Offline access** with full content archival
- **Tagging and organization** for retrieval
- **Estimated reading time** for planning
- **Weekly digest** of saved but unread items

### 10.3 Hootsuite Streams

Professional social media management approach:
- **Multi-column layout** for parallel monitoring
- **Custom filtered streams** by keyword, hashtag, or account
- **Unified inbox** for all mentions and DMs
- **Assignment and workflow** for team collaboration

### 10.4 Tweetdeck/X Pro

Power user features:
- **Real-time streaming** columns
- **Advanced search operators** for filtering
- **Scheduled posting** integration
- **Multi-account management**
- **Notification column** separate from feed

---

## 11. Implementation Priorities

### Phase 1: Foundation
1. Streaming data ingestion pipeline
2. Basic ranking algorithm (engagement + recency)
3. Account categorization with Twitter Lists sync
4. Simple bookmark functionality

### Phase 2: Intelligence
1. User interest model with TF-IDF
2. Priority scoring for accounts
3. Smart notification filtering
4. Thread reconstruction

### Phase 3: Advanced
1. Velocity-based trending detection
2. AI-powered auto-categorization
3. Engagement analytics dashboard
4. Personalized recommendations

### Phase 4: Polish
1. Offline support
2. Advanced scheduling and workflows
3. Team/sharing features
4. API for third-party integrations

---

## References

- [Twitter API Conversation ID Documentation](https://developer.twitter.com/en/docs/twitter-api/conversation-id)
- [Twitter API Rate Limits](https://docs.x.com/x-api/fundamentals/rate-limits)
- [Feedly AI and Mute Filters](https://feedly.com/new-features/posts/feedly-ai-and-mute-filters)
- [Social Media Algorithm Guide - Hootsuite](https://blog.hootsuite.com/social-media-algorithm/)
- [Social Media Metrics - Sprout Social](https://sproutsocial.com/insights/social-media-metrics/)
- [Twitter Database Design - GeeksforGeeks](https://www.geeksforgeeks.org/dbms/how-to-design-a-database-for-twitter/)
- [Infinite Scroll Best Practices - Justinmind](https://www.justinmind.com/ui-design/infinite-scroll)
- [Message Queue vs Streaming - Iron.io](https://blog.iron.io/message-queue-vs-streaming/)
- [TF-IDF for Recommendations - Medium](https://medium.com/codex/how-to-generate-recommendations-using-tf-idf-52d46eca606f)
- [Read-it-Later Apps - Zapier](https://zapier.com/blog/best-bookmaking-read-it-later-app/)
