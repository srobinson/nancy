# X/Twitter API Options for Local Feed Monitoring

**Research Date**: January 2025
**Purpose**: Evaluate all available methods to access Twitter/X data programmatically for a local-only personal feed monitoring application.

---

## Executive Summary

Accessing Twitter/X data in 2024-2025 has become significantly more challenging and expensive following major API pricing changes under Elon Musk's ownership. The key findings are:

1. **Official X API Free Tier is POST-only** - You cannot read tweets, timelines, or mentions without paying
2. **Basic Tier ($200/month)** provides read access but is expensive for personal use
3. **Third-party alternatives** like TwitterAPI.io offer 96% cost savings ($0.15/1000 tweets)
4. **Nitter is largely defunct** since January 2024, though some instances survive
5. **For personal/local use**, third-party scraping APIs or RSS bridges are the most practical options

**Recommendation for Local Personal Use**: Use a third-party API service like TwitterAPI.io or SocialData.tools with pay-as-you-go pricing, or self-host an RSS bridge solution.

---

## 1. Official X/Twitter API v2

### Pricing Tiers (as of October 2024)

| Tier | Monthly Cost | Annual Cost | Read Limit | Write Limit | Key Features |
|------|--------------|-------------|------------|-------------|--------------|
| **Free** | $0 | $0 | None (POST only) | 1,500 tweets/month | Login with Twitter, GET /2/users/me only |
| **Basic** | $200 | $2,100 ($175/mo) | 15,000 tweets/month | 50,000 tweets/month | Timeline read, mentions, reposts_of_me, communities search |
| **Pro** | $5,000 | $54,000 ($4,500/mo) | 1M tweets/month | Full access | Full v2 access, streaming |
| **Enterprise** | $42,000+ | Custom | 50M+ tweets/month | Custom | Dedicated support, full firehose |

### Rate Limits

**Free Tier**:
- POST /2/tweets: 17 requests per 24 hours (per user AND per app)
- Very restrictive, 24-hour windows

**Basic/Pro Tiers**:
- 15-minute rolling windows (much more generous)
- Monthly post consumption quota for search/stream endpoints

### What You Can Access by Tier

**Free Tier (POST-Only)**:
- Post tweets on behalf of users
- Login with Twitter (OAuth)
- GET /2/users/me (your own profile only)
- **Cannot**: Read timelines, search tweets, access mentions, view followers/following

**Basic Tier ($200/month)**:
- User Tweet timeline (up to 3,200 most recent)
- User mention timeline (up to 800 most recent)
- Recent search (last 7 days)
- Followers/following lists
- reposts_of_me endpoint
- Communities search

**Pro Tier ($5,000/month)**:
- Full archive search (all time)
- Streaming API
- Higher rate limits
- All v2 endpoints

### Endpoint Details

| Endpoint | Description | Historical Limit | Tier Required |
|----------|-------------|------------------|---------------|
| User Tweet Timeline | User's posted tweets | 3,200 tweets | Basic+ |
| User Mention Timeline | Tweets mentioning user | 800 mentions | Basic+ |
| Reverse Chronological Timeline | Home feed | Varies | Basic+ |
| Recent Search | Search last 7 days | 7 days | Basic+ |
| Full Archive Search | Search all time | Unlimited | Pro+ |
| Followers/Following | User connections | All | Basic+ |

---

## 2. Authentication Methods

### OAuth 2.0 Bearer Token (App-Only)

Best for: Read-only access to public data, server-to-server communication.

```python
import requests

BEARER_TOKEN = "your_bearer_token_here"

headers = {
    "Authorization": f"Bearer {BEARER_TOKEN}"
}

response = requests.get(
    "https://api.x.com/2/tweets?ids=1261326399320715264",
    headers=headers
)
```

**Characteristics**:
- Simple to implement
- No user context needed
- Read-only access to public information
- Rate limited at the App level

### OAuth 2.0 Authorization Code Flow with PKCE (User Context)

Best for: Acting on behalf of users, accessing private data, posting tweets.

```python
# Using Tweepy with OAuth 2.0 PKCE
import tweepy

client = tweepy.Client(
    consumer_key="YOUR_API_KEY",
    consumer_secret="YOUR_API_SECRET",
    access_token="USER_ACCESS_TOKEN",
    access_token_secret="USER_ACCESS_SECRET"
)

# Get user's timeline
tweets = client.get_users_tweets(id="USER_ID")
```

**Key Points**:
- Access tokens expire after 2 hours (7200 seconds)
- Use refresh_token to renew without re-authentication
- Required scopes: `tweet.read`, `users.read`, `follows.read`, `offline.access`
- Callback URL must be configured in Developer Portal

### OAuth 1.0a (Legacy)

Still supported for backwards compatibility. Required for some v1.1 endpoints.

### Obtaining Credentials

1. Create a Twitter Developer account at developer.x.com
2. Create a Project and App in the Developer Portal
3. Navigate to "Keys and Tokens" tab
4. Generate:
   - API Key and Secret (Consumer credentials)
   - Bearer Token (for app-only auth)
   - Access Token and Secret (for user auth)

**Security Best Practices**:
- Store credentials in environment variables
- Never commit tokens to version control
- Rotate bearer tokens periodically
- Use POST oauth2/invalidate_token to revoke compromised tokens

---

## 3. Third-Party Python Libraries

### Tweepy

The most popular Python library for Twitter API.

**Pros**:
- Mature, well-documented (v4.14+ supports API v2)
- Large community support
- Handles OAuth complexity
- Streaming support

**Cons**:
- Still requires official API access
- Rate limit handling can be manual
- Some v2 features lag behind official API

```python
import tweepy

# OAuth 2.0 Bearer Token (App-only)
client = tweepy.Client(bearer_token="YOUR_BEARER_TOKEN")

# Get user's recent tweets
tweets = client.get_users_tweets(
    id="USER_ID",
    max_results=100,
    tweet_fields=["created_at", "public_metrics"]
)

for tweet in tweets.data:
    print(f"{tweet.created_at}: {tweet.text}")
```

```python
# OAuth 2.0 with User Context (for timeline access)
client = tweepy.Client(
    consumer_key="API_KEY",
    consumer_secret="API_SECRET",
    access_token="ACCESS_TOKEN",
    access_token_secret="ACCESS_SECRET"
)

# Get mentions
mentions = client.get_users_mentions(id="USER_ID")
```

### python-twitter-v2 (pytwitter)

Alternative library specifically for API v2.

**Pros**:
- Designed specifically for v2 API
- Active maintenance (v0.9.3 released Nov 2025)
- Clean API design

**Cons**:
- Smaller community than Tweepy
- Less documentation

```python
from pytwitter import Api

api = Api(bearer_token="YOUR_BEARER_TOKEN")

# Get user by username
user = api.get_user(username="twitter")

# Get user's tweets
tweets = api.get_timelines(user_id=user.data.id)
```

### twarc / twarc2

Command-line tool and Python library, popular in research/academic contexts.

**Pros**:
- Excellent for data collection
- Good for archiving
- Academic community support

**Cons**:
- More focused on data collection than app integration
- Command-line oriented

### Library Comparison

| Library | Stars | API v2 Support | Streaming | Best For |
|---------|-------|----------------|-----------|----------|
| Tweepy | 10k+ | Full (v4.0+) | Yes | General purpose |
| pytwitter | 600+ | Full | Yes | Clean v2 implementation |
| twarc2 | 1.3k+ | Full | Yes | Research/archiving |

---

## 4. Alternative Approaches

### Third-Party Scraping APIs

These services bypass official API limitations through scraping/data aggregation.

#### TwitterAPI.io

**Pricing**: Pay-as-you-go, ~$0.15 per 1,000 tweets
**No Twitter authentication required**

**Pros**:
- 96% cheaper than official API
- No approval process needed
- ~800ms response times
- 99.99% uptime SLA
- Webhook support

**Cons**:
- Third-party dependency
- Terms of service gray area
- Data freshness may vary

```python
import requests

response = requests.get(
    "https://api.twitterapi.io/twitter/user/tweets",
    params={"userName": "elonmusk"},
    headers={"X-API-Key": "YOUR_API_KEY"}
)
tweets = response.json()
```

#### SocialData.tools

Similar scraping API with competitive pricing.

#### Bright Data

**Cost**: ~$0.0009 per record
Enterprise-grade scraping infrastructure.

#### Cost Comparison

| Service | Cost per 10K tweets | Monthly for 100K tweets |
|---------|---------------------|-------------------------|
| Official Basic | Included (15K limit) | $200 |
| Official Pro | Included (1M limit) | $5,000 |
| TwitterAPI.io | $1.50 | $15 |
| Bright Data | $9 | $90 |
| SociaVault | ~$10-50 | Varies |

### Nitter and Privacy Front-ends

**Current Status (2025)**: Largely defunct since January 2024.

Twitter removed the guest API that Nitter relied upon. Running a Nitter instance now requires real Twitter session tokens.

**Still Working** (as of Jan 2025):
- xcancel.com (intermittently)
- Some self-hosted instances

**Self-Hosting Nitter**:
```bash
# Requires obtaining session tokens from real accounts
# See: https://github.com/zedeus/nitter

docker pull zedeus/nitter
# Configure with session tokens
docker run -p 8080:8080 nitter
```

**Verdict**: Not reliable for production use; good for hobbyist experimentation only.

### RSS Bridges

**RSSBridge** can generate RSS feeds from Twitter (when functional).

```bash
# Self-host RSSBridge
docker pull rssbridge/rss-bridge
docker run -p 3000:80 rssbridge/rss-bridge
```

**Limitations**:
- Depends on scraping methods that frequently break
- Limited functionality
- Not suitable for high-volume needs

### Browser Automation

Using Playwright/Puppeteer/Selenium to automate browser interactions.

**Pros**:
- Works when other methods fail
- Full access to what a user can see

**Cons**:
- Slow and resource-intensive
- Brittle (breaks with UI changes)
- Violates Terms of Service
- IP blocking risk

```python
from playwright.sync_api import sync_playwright

def scrape_timeline(username):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(f"https://twitter.com/{username}")
        # Wait for tweets to load
        page.wait_for_selector('[data-testid="tweet"]')
        tweets = page.query_selector_all('[data-testid="tweet"]')
        # Extract text...
        browser.close()
```

### Mobile Apps as Alternatives

**Fritter** (Android): Open-source Twitter client, no account needed.
**Squawker**: Open-source anonymous X client.

These can't be used programmatically but provide inspiration for approaches.

---

## 5. Data Access Summary

### What Data Can You Access?

| Data Type | Free | Basic | Pro | Third-Party APIs |
|-----------|------|-------|-----|------------------|
| Post tweets | Yes (1.5K/mo) | Yes (50K/mo) | Yes | N/A |
| Read own profile | Yes | Yes | Yes | Yes |
| User timelines | No | Yes (15K/mo) | Yes (1M/mo) | Yes |
| Mentions | No | Yes | Yes | Yes |
| Search tweets | No | 7 days | Full archive | Yes |
| Followers/Following | No | Yes | Yes | Yes |
| Home timeline | No | Yes | Yes | Difficult |
| Streaming | No | No | Yes | Some |
| Likes | No | Limited | Yes | Yes |
| Direct Messages | No | No | Yes | No |

### Historical Data Limits

- **User Timeline**: 3,200 most recent tweets
- **Mentions**: 800 most recent mentions
- **Search**: 7 days (Basic), unlimited (Pro)

---

## 6. Cost Analysis for Personal Use

### Scenario: Monitor 5 accounts, check every 15 minutes

**Monthly API calls needed**:
- 4 checks/hour x 24 hours x 30 days x 5 accounts = 14,400 requests
- Plus user profile lookups, mentions: ~20,000 total requests/month

| Option | Monthly Cost | Feasibility |
|--------|--------------|-------------|
| Official Free | $0 | Impossible (no read access) |
| Official Basic | $200 | Overkill for personal use |
| TwitterAPI.io | ~$3 | Best value |
| Bright Data | ~$18 | Good value |
| Self-hosted Nitter | $0 + hosting | Unreliable |

### Break-Even Analysis

If you need less than 75,000 tweets/month, third-party APIs are cheaper than Basic tier.
If you need 500,000+ tweets/month, Pro tier may become competitive.

---

## 7. Recommendations for Local-Only Personal Use

### Best Option: Third-Party API (TwitterAPI.io or similar)

**Why**:
- Pay-as-you-go eliminates waste
- No approval process
- ~$3-15/month for typical personal use
- Simple REST API integration

**Implementation**:
```python
import requests
import schedule
import time

API_KEY = "your_twitterapi_io_key"
ACCOUNTS_TO_MONITOR = ["account1", "account2"]

def fetch_tweets(username):
    response = requests.get(
        "https://api.twitterapi.io/twitter/user/tweets",
        params={"userName": username, "count": 20},
        headers={"X-API-Key": API_KEY}
    )
    return response.json()

def monitor_feeds():
    for account in ACCOUNTS_TO_MONITOR:
        tweets = fetch_tweets(account)
        # Process tweets locally
        for tweet in tweets.get("data", []):
            print(f"[{account}] {tweet['text'][:100]}")

# Check every 15 minutes
schedule.every(15).minutes.do(monitor_feeds)

while True:
    schedule.run_pending()
    time.sleep(60)
```

### Alternative: Official Basic Tier

**When to consider**:
- You need guaranteed uptime/SLA
- Compliance/legal requirements
- Building something you might share publicly later

**Implementation with Tweepy**:
```python
import tweepy
import os

client = tweepy.Client(
    bearer_token=os.environ["TWITTER_BEARER_TOKEN"],
    consumer_key=os.environ["TWITTER_API_KEY"],
    consumer_secret=os.environ["TWITTER_API_SECRET"],
    access_token=os.environ["TWITTER_ACCESS_TOKEN"],
    access_token_secret=os.environ["TWITTER_ACCESS_SECRET"]
)

# Get timeline for followed accounts
def get_home_timeline():
    tweets = client.get_home_timeline(max_results=100)
    return tweets.data

# Get mentions
def get_mentions(user_id):
    mentions = client.get_users_mentions(id=user_id, max_results=100)
    return mentions.data
```

### Budget Option: RSS Bridge + Caching

**For minimal usage**:
- Self-host RSSBridge
- Cache aggressively
- Accept that it may break periodically

### Not Recommended for Production

- Nitter (unreliable since 2024)
- Browser automation (brittle, resource-heavy)
- Scraping directly (IP blocking, ToS violations)

---

## 8. Legal and Terms of Service Considerations

### Official API
- Clear terms of service
- Compliant by definition
- Data usage restrictions apply

### Third-Party Scraping APIs
- Legal gray area
- Risk of service interruption
- Check each provider's terms

### Self-Scraping
- Explicitly prohibited by X ToS
- Risk of account/IP bans
- May violate CFAA in some jurisdictions

**For personal local use**: Third-party APIs generally carry minimal practical risk, but be aware of the legal ambiguity.

---

## Resources and Links

- [X API Documentation](https://developer.x.com/en/docs)
- [X API Pricing](https://developer.x.com/en/products/twitter-api)
- [Tweepy Documentation](https://docs.tweepy.org/)
- [TwitterAPI.io](https://twitterapi.io/)
- [python-twitter-v2 (pytwitter)](https://pypi.org/project/python-twitter-v2/)
- [Nitter GitHub](https://github.com/zedeus/nitter)
- [RSSBridge](https://github.com/RSS-Bridge/rss-bridge)

---

## Conclusion

For a local-only personal feed monitoring app in 2025, **the official X API is prohibitively expensive** at $200/month for basic read access. Third-party services like TwitterAPI.io offer a 96% cost reduction with pay-as-you-go pricing that better suits personal use cases.

The recommended approach is:
1. Start with a third-party API for cost efficiency
2. Implement local caching to minimize API calls
3. Keep Tweepy code structure so you can switch to official API if needed
4. Monitor for service changes, as this landscape evolves rapidly
