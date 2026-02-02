---
Based on my research, I now have enough information to provide you with comprehensive examples. Let me compile the findings.
---

# Linear GraphQL API - Query and Mutation Examples

## Overview

- **Endpoint**: `https://api.linear.app/graphql`
- **Authentication**: Pass API key directly in the `Authorization` header

---

## 1. Get Next TODO Issue for a Project

### GraphQL Query

```bash
query GetNextTodoIssue($projectName: String!, $stateName: String!) {
  issues(
    filter: {
      project: { name: { eq: $projectName } }
      state: { name: { eq: $stateName } }
      assignee: { null: false }
    }
    first: 1
    orderBy: createdAt
  ) {
    nodes {
      id
      identifier
      title
      description
      priority
      priorityLabel
      url
      state {
        id
        name
        type
      }
      assignee {
        id
        name
        email
      }
      project {
        id
        name
      }
      parent {
        id
        identifier
        title
        description
      }
    }
  }
}
```

### Variables

```json
{
  \"projectName\": \"mdcontext\",
  \"stateName\": \"Todo\"
}
```

### curl Example

```bash
curl -X POST \\
  -H \"Content-Type: application/json\" \\
  -H \"Authorization: lin_api_XXXXXXXXXXXXXXXXXXXXXXXXXXXX\" \\
  --data '{
    \"query\": \"query GetNextTodoIssue($projectName: String!, $stateName: String!) { issues(filter: { project: { name: { eq: $projectName } } state: { name: { eq: $stateName } } assignee: { null: false } } first: 1 orderBy: createdAt) { nodes { id identifier title description priority priorityLabel url state { id name type } assignee { id name email } project { id name } parent { id identifier title description } } } }\",
    \"variables\": {
      \"projectName\": \"mdcontext\",
      \"stateName\": \"Todo\"
    }
  }' \\
  https://api.linear.app/graphql
```

### Important Notes on Priority Ordering

Linear's GraphQL API has limited `orderBy` options (only `createdAt` and `updatedAt`). To truly order by priority (highest first), you have two options:

**Option A**: Filter for high-priority issues only, then sort client-side:

```graphql
query GetHighPriorityTodoIssues($projectName: String!, $stateName: String!) {
  issues(
    filter: {
      project: { name: { eq: $projectName } }
      state: { name: { eq: $stateName } }
      assignee: { null: false }
      priority: { lte: 2, neq: 0 }
    }
    first: 10
  ) {
    nodes {
      id
      identifier
      title
      description
      priority
      priorityLabel
      parent {
        id
        identifier
        title
        description
      }
    }
  }
}
```

**Priority Values**:

- `0` = No priority
- `1` = Urgent
- `2` = High
- `3` = Normal/Medium
- `4` = Low

**Option B**: Fetch multiple issues and sort client-side by the `priority` field (lower number = higher priority).

---

## 2. Add Comment to Issue

### GraphQL Mutation

```graphql
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment {
      id
      body
      createdAt
      user {
        id
        name
      }
      issue {
        id
        identifier
        title
      }
    }
  }
}
```

### Variables

````json
{
  \"issueId\": \"issue-uuid-here\",
  \"body\": \"## Status Update\
\
This is a **markdown** comment with:\
- Bullet points\
- `code snippets`\
\
```javascript\
console.log('Hello');\
```\"
}
````

### curl Example

```bash
curl -X POST \\
  -H \"Content-Type: application/json\" \\
  -H \"Authorization: lin_api_XXXXXXXXXXXXXXXXXXXXXXXXXXXX\" \\
  --data '{
    \"query\": \"mutation CreateComment($issueId: String!, $body: String!) { commentCreate(input: { issueId: $issueId body: $body }) { success comment { id body createdAt user { id name } issue { id identifier title } } } }\",
    \"variables\": {
      \"issueId\": \"abc123-uuid-here\",
      \"body\": \"## Status Update\
\
This is a **markdown** comment.\"
    }
  }' \\
  https://api.linear.app/graphql
```

---

## Authentication Details

### Using Personal API Key

```bash
# API key goes directly in Authorization header (no \"Bearer\" prefix)
-H \"Authorization: lin_api_XXXXXXXXXXXXXXXXXXXXXXXXXXXX\"
```

### Using OAuth2 Token

```bash
# OAuth tokens use \"Bearer\" prefix
-H \"Authorization: Bearer YOUR_OAUTH_TOKEN\"
```

### Getting Your API Key

1. Go to Linear Settings > Security & Access > API
2. Create a new Personal API key
3. Copy the key (format: `lin_api_...`)

---

## Filter Comparators Reference

| Comparator   | Description           | Example                                                     |
| ------------ | --------------------- | ----------------------------------------------------------- |
| `eq`         | Equals                | `{ name: { eq: \"Todo\" } }`                                |
| `neq`        | Not equals            | `{ priority: { neq: 0 } }`                                  |
| `in`         | In list               | `{ state: { type: { in: [\"started\", \"unstarted\"] } } }` |
| `nin`        | Not in list           | `{ priority: { nin: [0, 4] } }`                             |
| `lt`         | Less than             | `{ priority: { lt: 3 } }`                                   |
| `lte`        | Less than or equal    | `{ priority: { lte: 2 } }`                                  |
| `gt`         | Greater than          | `{ createdAt: { gt: \"2024-01-01\" } }`                     |
| `gte`        | Greater than or equal | `{ updatedAt: { gte: \"2024-01-01\" } }`                    |
| `null`       | Is null/not null      | `{ assignee: { null: false } }`                             |
| `contains`   | String contains       | `{ title: { contains: \"bug\" } }`                          |
| `startsWith` | String starts with    | `{ identifier: { startsWith: \"ENG\" } }`                   |

---

## Complete Working Example - Get Next Task

Here is a complete, copy-paste ready script:

```bash
#!/bin/bash

# Configuration
LINEAR_API_KEY=\"lin_api_YOUR_KEY_HERE\"
PROJECT_NAME=\"mdcontext\"
STATE_NAME=\"Todo\"

# GraphQL query (minified)
QUERY='query($projectName:String!,$stateName:String!){issues(filter:{project:{name:{eq:$projectName}}state:{name:{eq:$stateName}}assignee:{null:false}}first:1){nodes{id identifier title description priority priorityLabel url state{id name}assignee{id name}parent{id identifier title description}}}}'

# Execute request
curl -s -X POST \\
  -H \"Content-Type: application/json\" \\
  -H \"Authorization: $LINEAR_API_KEY\" \\
  --data \"{
    \\\"query\\\": \\\"$QUERY\\\",
    \\\"variables\\\": {
      \\\"projectName\\\": \\\"$PROJECT_NAME\\\",
      \\\"stateName\\\": \\\"$STATE_NAME\\\"
    }
  }\" \\
  https://api.linear.app/graphql | jq .
```

---

## Sources

- [Linear Developer Documentation - Getting Started](https://linear.app/developers/graphql)
- [Linear Developer Documentation - Filtering](https://linear.app/developers/filtering)
- [Linear Developer Documentation - Pagination](https://linear.app/developers/pagination)
- [Linear API Schema Explorer (Apollo Studio)](https://studio.apollographql.com/public/Linear-API/schema/reference?variant=current)
- [Linear API Documentation](https://linear.app/developers)
- [Linear GitHub - SDK Schema](https://github.com/linear/linear/blob/master/packages/sdk/src/schema.graphql)

Yes, exactly. Here's the third one:

## 3. Update Issue Status

```bash
curl -s -X POST \\
  -H \"Content-Type: application/json\" \\
  -H \"Authorization: $LINEAR_API_KEY\" \\
  --data '{
    \"query\": \"mutation { issueUpdate(id: \\\"issue-uuid-here\\\" input: { stateId: \\\"in-progress-state-uuid\\\" }) { success issue { id identifier state { name } } } }\"
  }' \\
  https://api.linear.app/graphql
```

**Gotcha:** Need the state UUID, not the name. One-time query to get state IDs:

```bash
curl -s -X POST \\
  -H \"Content-Type: application/json\" \\
  -H \"Authorization: $LINEAR_API_KEY\" \\
  --data '{
    \"query\": \"query { workflowStates(filter: { team: { name: { eq: \\\"Alphabio\\\" } } }) { nodes { id name type } } }\"
  }' \\
  https://api.linear.app/graphql
```

Then hardcode in config:

```bash
STATE_TODO=\"uuid-1\"
STATE_IN_PROGRESS=\"uuid-2\"
```

---

**Complete set:**

| Operation              | When                      |
| ---------------------- | ------------------------- |
| Get next assigned Todo | Ralph loop starts         |
| Update to In Progress  | Worker claims issue       |
| Add comment            | Progress/blocker/complete |

GitHub handles the rest (In Review on PR, Done on merge).
