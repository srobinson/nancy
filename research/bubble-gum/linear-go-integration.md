# Linear API Integration with Go

**Research Date:** January 2026
**Purpose:** Evaluate options for integrating with Linear's project management API using Go

## Executive Summary

Linear does **not provide an official Go SDK**. Their official SDK is TypeScript-based. For Go projects, you have three main approaches:

1. **Community Go Libraries** - Pre-built packages (varying quality/maintenance)
2. **Generic GraphQL Clients** - Use established Go GraphQL libraries with Linear's API
3. **Code Generation** - Generate type-safe clients from Linear's GraphQL schema

**Recommendation:** For production use, combine **Khan/genqlient** (code generation) or **hasura/go-graphql-client** with Linear's publicly available GraphQL schema.

---

## Table of Contents

1. [Authentication](#authentication)
2. [Community Go Libraries](#community-go-libraries)
3. [Generic GraphQL Client Approaches](#generic-graphql-client-approaches)
4. [Code Generation with genqlient](#code-generation-with-genqlient)
5. [Common Operations](#common-operations)
6. [Rate Limits](#rate-limits)
7. [Complete Example Project](#complete-example-project)
8. [Recommendations](#recommendations)

---

## Authentication

Linear supports two authentication methods:

### Personal API Keys (Simple Scripts)

Best for personal automation and scripts. Create keys in Linear's Security & access settings.

```go
// Simple API key authentication
client := resty.New()
client.SetHeader("Authorization", "lin_api_YOUR_KEY_HERE")
client.SetHeader("Content-Type", "application/json")
```

### OAuth 2.0 (Applications)

Required for applications serving multiple users.

**Important Changes (October 2025):**
- New OAuth apps issue refresh tokens by default
- Access tokens valid for 24 hours only
- Existing apps must migrate by April 1, 2026

```go
package main

import (
    "context"
    "golang.org/x/oauth2"
    "net/http"
)

var linearOAuthConfig = &oauth2.Config{
    ClientID:     "YOUR_CLIENT_ID",
    ClientSecret: "YOUR_CLIENT_SECRET",
    Endpoint: oauth2.Endpoint{
        AuthURL:  "https://linear.app/oauth/authorize",
        TokenURL: "https://api.linear.app/oauth/token",
    },
    RedirectURL: "https://yourapp.com/callback",
    Scopes:      []string{"read", "write"},
}

func getAuthenticatedClient(ctx context.Context, token *oauth2.Token) *http.Client {
    // TokenSource handles automatic refresh
    tokenSource := linearOAuthConfig.TokenSource(ctx, token)
    return oauth2.NewClient(ctx, tokenSource)
}
```

### Client Credentials Flow (Server-to-Server)

For server-to-server communication without user interaction:

```go
// Tokens valid for 30 days, no refresh token
// Must fetch new token on 401 response
data := url.Values{}
data.Set("grant_type", "client_credentials")
data.Set("client_id", clientID)
data.Set("client_secret", clientSecret)

resp, err := http.PostForm("https://api.linear.app/oauth/token", data)
```

---

## Community Go Libraries

### 1. github.com/guillermo/linear

**Status:** Community-maintained, basic functionality

```bash
go get github.com/guillermo/linear/linear-api
```

**Pros:**
- Provides typed structs for Linear entities (Issue, Team, User, etc.)
- Includes `FetchIssues` and other helper functions

**Cons:**
- Limited documentation
- Uncertain maintenance status
- May not cover all API operations

```go
import linear "github.com/guillermo/linear/linear-api"

// Basic usage
client := linear.DefaultClient()
issues, err := linear.FetchIssues(client, ctx, filter, /* ... */)
```

### 2. github.com/geropl/linear-mcp-go

**Status:** Active development (v1.11.0 as of August 2025)

A Model Context Protocol (MCP) server for Linear written in Go. While designed for AI assistants, its codebase demonstrates solid patterns for Linear API integration.

**Supported Operations:**
- `linear_search_issues` - Flexible issue searching
- `linear_get_user_issues` - Retrieve assigned issues
- `linear_get_issue` - Fetch single issue details
- `linear_get_issue_comments` - Retrieve comments with threading
- `linear_get_teams` - List teams
- `linear_create_issue` - Create issues with sub-issue support
- `linear_update_issue` - Modify issue properties
- `linear_add_comment` - Post comments

**Setup:**
```bash
export LINEAR_API_KEY=your_linear_api_key
./linear-mcp-go serve --write-access
```

### 3. github.com/wadeling/linear-webhook/api/linear

Provides Go types for Linear webhooks (useful for receiving events).

---

## Generic GraphQL Client Approaches

Since Linear uses GraphQL, any Go GraphQL client works. Here are the top options:

### Option A: machinebox/graphql (Simple, Low-Level)

**Best for:** Quick prototypes, simple integrations

```bash
go get github.com/machinebox/graphql
```

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/machinebox/graphql"
)

const linearEndpoint = "https://api.linear.app/graphql"

func main() {
    client := graphql.NewClient(linearEndpoint)

    // Create request
    req := graphql.NewRequest(`
        query {
            viewer {
                id
                name
                email
            }
        }
    `)

    // Set authentication header
    req.Header.Set("Authorization", "lin_api_YOUR_KEY_HERE")

    // Define response structure
    var resp struct {
        Viewer struct {
            ID    string `json:"id"`
            Name  string `json:"name"`
            Email string `json:"email"`
        } `json:"viewer"`
    }

    // Execute
    ctx := context.Background()
    if err := client.Run(ctx, req, &resp); err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Logged in as: %s (%s)\n", resp.Viewer.Name, resp.Viewer.Email)
}
```

### Option B: hasura/go-graphql-client (Feature-Rich)

**Best for:** Complex integrations, subscriptions needed

```bash
go get github.com/hasura/go-graphql-client
```

```go
package main

import (
    "context"
    "fmt"
    "net/http"

    "github.com/hasura/go-graphql-client"
)

func main() {
    httpClient := &http.Client{
        Transport: &authTransport{
            apiKey: "lin_api_YOUR_KEY_HERE",
            base:   http.DefaultTransport,
        },
    }

    client := graphql.NewClient("https://api.linear.app/graphql", httpClient)

    var query struct {
        Viewer struct {
            ID    graphql.ID
            Name  graphql.String
            Email graphql.String
        }
    }

    err := client.Query(context.Background(), &query, nil)
    if err != nil {
        panic(err)
    }

    fmt.Printf("User: %s\n", query.Viewer.Name)
}

// Custom transport for authentication
type authTransport struct {
    apiKey string
    base   http.RoundTripper
}

func (t *authTransport) RoundTrip(req *http.Request) (*http.Response, error) {
    req.Header.Set("Authorization", t.apiKey)
    return t.base.RoundTrip(req)
}
```

### Option C: go-resty (HTTP Client Approach)

**Best for:** When you want full control over requests

```bash
go get github.com/go-resty/resty/v2
```

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"

    "github.com/go-resty/resty/v2"
)

const baseURL = "https://api.linear.app/graphql"

type GraphQLRequest struct {
    Query     string                 `json:"query"`
    Variables map[string]interface{} `json:"variables,omitempty"`
}

type GraphQLResponse struct {
    Data   json.RawMessage `json:"data"`
    Errors []struct {
        Message string `json:"message"`
    } `json:"errors,omitempty"`
}

func main() {
    client := resty.New()
    client.SetHeader("Authorization", "lin_api_YOUR_KEY_HERE")
    client.SetHeader("Content-Type", "application/json")

    query := `
        query GetTeams {
            teams {
                nodes {
                    id
                    name
                    key
                }
            }
        }
    `

    var result GraphQLResponse
    resp, err := client.R().
        SetBody(GraphQLRequest{Query: query}).
        SetResult(&result).
        Post(baseURL)

    if err != nil {
        log.Fatal(err)
    }

    if len(result.Errors) > 0 {
        log.Fatalf("GraphQL errors: %v", result.Errors)
    }

    fmt.Printf("Response: %s\n", string(result.Data))
}
```

---

## Code Generation with genqlient

**Best for:** Production applications requiring type safety

[Khan/genqlient](https://github.com/Khan/genqlient) generates type-safe Go code from GraphQL schemas.

### Setup

1. Install genqlient:
```bash
go install github.com/Khan/genqlient@latest
```

2. Download Linear's GraphQL schema:
```bash
# From Linear's GitHub or via introspection
curl -H "Authorization: lin_api_YOUR_KEY" \
     -H "Content-Type: application/json" \
     -d '{"query": "{ __schema { types { name } } }"}' \
     https://api.linear.app/graphql > schema.graphql
```

Or get it from: https://github.com/linear/linear/blob/master/packages/sdk/src/schema.graphql

3. Create `genqlient.yaml`:
```yaml
schema: schema.graphql
operations:
  - "operations/*.graphql"
generated: generated/linear.go
package: linear
```

4. Create operations file (`operations/issues.graphql`):
```graphql
query GetIssues($teamId: String!) {
    team(id: $teamId) {
        issues {
            nodes {
                id
                title
                state {
                    name
                }
            }
        }
    }
}

mutation CreateIssue($title: String!, $teamId: String!, $description: String) {
    issueCreate(input: {
        title: $title
        teamId: $teamId
        description: $description
    }) {
        success
        issue {
            id
            title
            identifier
        }
    }
}
```

5. Generate code:
```bash
genqlient
```

6. Use generated code:
```go
package main

import (
    "context"
    "yourproject/generated/linear"
    "net/http"
)

func main() {
    httpClient := &http.Client{/* with auth */}
    client := linear.NewClient("https://api.linear.app/graphql", httpClient)

    // Type-safe, auto-completed
    resp, err := linear.GetIssues(context.Background(), client, "team-uuid")
    if err != nil {
        panic(err)
    }

    for _, issue := range resp.Team.Issues.Nodes {
        fmt.Printf("%s: %s\n", issue.Id, issue.Title)
    }
}
```

---

## Common Operations

### List Issues

```go
query := `
query ListIssues($teamId: String!) {
    team(id: $teamId) {
        issues(first: 50) {
            nodes {
                id
                identifier
                title
                description
                state {
                    id
                    name
                    type
                }
                assignee {
                    id
                    name
                }
                priority
                createdAt
                updatedAt
            }
            pageInfo {
                hasNextPage
                endCursor
            }
        }
    }
}
`
```

### Filter Issues

```go
// High priority issues
query := `
query HighPriorityIssues {
    issues(filter: {
        priority: { lte: 2, neq: 0 }
    }) {
        nodes {
            id
            title
            priority
        }
    }
}
`

// Issues by state
query := `
query IssuesByState($stateId: ID!) {
    issues(filter: { state: { id: { eq: $stateId } } }) {
        nodes {
            id
            title
        }
    }
}
`

// Overdue issues
query := `
query OverdueIssues {
    issues(filter: {
        dueDate: { lt: "2026-01-23" }
        state: { type: { nin: ["completed", "canceled"] } }
    }) {
        nodes {
            id
            title
            dueDate
        }
    }
}
`
```

### Create Issue

```go
mutation := `
mutation CreateIssue($input: IssueCreateInput!) {
    issueCreate(input: $input) {
        success
        issue {
            id
            identifier
            title
            url
        }
    }
}
`

variables := map[string]interface{}{
    "input": map[string]interface{}{
        "title":       "Implement user authentication",
        "description": "Add JWT-based auth to the API",
        "teamId":      "team-uuid-here",
        "priority":    2, // High
        "labelIds":    []string{"label-uuid"},
    },
}
```

### Update Issue Status

```go
// First, get workflow states for the team
statesQuery := `
query GetWorkflowStates($teamId: String!) {
    team(id: $teamId) {
        states {
            nodes {
                id
                name
                type
            }
        }
    }
}
`

// Then update the issue
mutation := `
mutation UpdateIssueStatus($issueId: String!, $stateId: String!) {
    issueUpdate(id: $issueId, input: { stateId: $stateId }) {
        success
        issue {
            id
            title
            state {
                name
            }
        }
    }
}
`
```

### Add Comment

```go
mutation := `
mutation AddComment($issueId: String!, $body: String!) {
    commentCreate(input: { issueId: $issueId, body: $body }) {
        success
        comment {
            id
            body
            createdAt
        }
    }
}
`
```

### Get Teams

```go
query := `
query GetTeams {
    teams {
        nodes {
            id
            name
            key
            states {
                nodes {
                    id
                    name
                    type
                }
            }
        }
    }
}
`
```

---

## Rate Limits

| Authentication | Request Limit | Complexity Limit |
|---------------|---------------|------------------|
| API Key | 1,500/hour/user | 250,000 points/hour |
| OAuth App | 500/hour/user/app | 250,000 points/hour |

**Best Practices:**
- Filter in GraphQL, not in code
- Use webhooks instead of polling
- Add delays between batch operations: `time.Sleep(100 * time.Millisecond)`

---

## Complete Example Project

```go
// main.go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "os"
    "time"

    "github.com/machinebox/graphql"
)

const linearAPI = "https://api.linear.app/graphql"

type LinearClient struct {
    client *graphql.Client
    apiKey string
}

func NewLinearClient(apiKey string) *LinearClient {
    return &LinearClient{
        client: graphql.NewClient(linearAPI),
        apiKey: apiKey,
    }
}

func (c *LinearClient) doRequest(ctx context.Context, query string, variables map[string]interface{}, resp interface{}) error {
    req := graphql.NewRequest(query)
    req.Header.Set("Authorization", c.apiKey)

    for k, v := range variables {
        req.Var(k, v)
    }

    return c.client.Run(ctx, req, resp)
}

// GetTeams returns all teams
func (c *LinearClient) GetTeams(ctx context.Context) ([]Team, error) {
    var resp struct {
        Teams struct {
            Nodes []Team `json:"nodes"`
        } `json:"teams"`
    }

    query := `
        query {
            teams {
                nodes {
                    id
                    name
                    key
                }
            }
        }
    `

    if err := c.doRequest(ctx, query, nil, &resp); err != nil {
        return nil, err
    }

    return resp.Teams.Nodes, nil
}

// GetIssues returns issues for a team
func (c *LinearClient) GetIssues(ctx context.Context, teamID string, limit int) ([]Issue, error) {
    var resp struct {
        Team struct {
            Issues struct {
                Nodes []Issue `json:"nodes"`
            } `json:"issues"`
        } `json:"team"`
    }

    query := `
        query($teamId: String!, $limit: Int!) {
            team(id: $teamId) {
                issues(first: $limit) {
                    nodes {
                        id
                        identifier
                        title
                        description
                        priority
                        state {
                            id
                            name
                            type
                        }
                        assignee {
                            id
                            name
                        }
                        createdAt
                        updatedAt
                    }
                }
            }
        }
    `

    vars := map[string]interface{}{
        "teamId": teamID,
        "limit":  limit,
    }

    if err := c.doRequest(ctx, query, vars, &resp); err != nil {
        return nil, err
    }

    return resp.Team.Issues.Nodes, nil
}

// CreateIssue creates a new issue
func (c *LinearClient) CreateIssue(ctx context.Context, input CreateIssueInput) (*Issue, error) {
    var resp struct {
        IssueCreate struct {
            Success bool  `json:"success"`
            Issue   Issue `json:"issue"`
        } `json:"issueCreate"`
    }

    query := `
        mutation($input: IssueCreateInput!) {
            issueCreate(input: $input) {
                success
                issue {
                    id
                    identifier
                    title
                    url
                }
            }
        }
    `

    vars := map[string]interface{}{
        "input": input,
    }

    if err := c.doRequest(ctx, query, vars, &resp); err != nil {
        return nil, err
    }

    if !resp.IssueCreate.Success {
        return nil, fmt.Errorf("failed to create issue")
    }

    return &resp.IssueCreate.Issue, nil
}

// UpdateIssueState updates an issue's workflow state
func (c *LinearClient) UpdateIssueState(ctx context.Context, issueID, stateID string) error {
    var resp struct {
        IssueUpdate struct {
            Success bool `json:"success"`
        } `json:"issueUpdate"`
    }

    query := `
        mutation($issueId: String!, $stateId: String!) {
            issueUpdate(id: $issueId, input: { stateId: $stateId }) {
                success
            }
        }
    `

    vars := map[string]interface{}{
        "issueId": issueID,
        "stateId": stateID,
    }

    if err := c.doRequest(ctx, query, vars, &resp); err != nil {
        return err
    }

    if !resp.IssueUpdate.Success {
        return fmt.Errorf("failed to update issue state")
    }

    return nil
}

// Types

type Team struct {
    ID   string `json:"id"`
    Name string `json:"name"`
    Key  string `json:"key"`
}

type Issue struct {
    ID          string    `json:"id"`
    Identifier  string    `json:"identifier"`
    Title       string    `json:"title"`
    Description string    `json:"description"`
    Priority    int       `json:"priority"`
    URL         string    `json:"url"`
    State       *State    `json:"state"`
    Assignee    *User     `json:"assignee"`
    CreatedAt   time.Time `json:"createdAt"`
    UpdatedAt   time.Time `json:"updatedAt"`
}

type State struct {
    ID   string `json:"id"`
    Name string `json:"name"`
    Type string `json:"type"`
}

type User struct {
    ID   string `json:"id"`
    Name string `json:"name"`
}

type CreateIssueInput struct {
    Title       string   `json:"title"`
    Description string   `json:"description,omitempty"`
    TeamID      string   `json:"teamId"`
    Priority    int      `json:"priority,omitempty"`
    LabelIDs    []string `json:"labelIds,omitempty"`
    AssigneeID  string   `json:"assigneeId,omitempty"`
}

func main() {
    apiKey := os.Getenv("LINEAR_API_KEY")
    if apiKey == "" {
        log.Fatal("LINEAR_API_KEY environment variable required")
    }

    client := NewLinearClient(apiKey)
    ctx := context.Background()

    // Get teams
    teams, err := client.GetTeams(ctx)
    if err != nil {
        log.Fatalf("Failed to get teams: %v", err)
    }

    fmt.Println("Teams:")
    for _, team := range teams {
        fmt.Printf("  - %s (%s)\n", team.Name, team.Key)
    }

    if len(teams) == 0 {
        return
    }

    // Get issues for first team
    issues, err := client.GetIssues(ctx, teams[0].ID, 10)
    if err != nil {
        log.Fatalf("Failed to get issues: %v", err)
    }

    fmt.Printf("\nIssues in %s:\n", teams[0].Name)
    for _, issue := range issues {
        state := "Unknown"
        if issue.State != nil {
            state = issue.State.Name
        }
        fmt.Printf("  - [%s] %s (%s)\n", issue.Identifier, issue.Title, state)
    }

    // Create a new issue
    newIssue, err := client.CreateIssue(ctx, CreateIssueInput{
        Title:       "Test issue from Go client",
        Description: "This issue was created via the Linear GraphQL API",
        TeamID:      teams[0].ID,
        Priority:    3, // Normal
    })
    if err != nil {
        log.Fatalf("Failed to create issue: %v", err)
    }

    fmt.Printf("\nCreated issue: %s - %s\n", newIssue.Identifier, newIssue.Title)
}
```

---

## Recommendations

### For Quick Scripts/Automation
Use **machinebox/graphql** or **go-resty**:
- Simple setup
- Minimal dependencies
- Good for one-off scripts

### For Production Applications
Use **Khan/genqlient**:
- Type-safe generated code
- Compile-time validation
- Best long-term maintainability
- Catches API changes at build time

### For AI/LLM Integration
Consider **geropl/linear-mcp-go**:
- Pre-built MCP server
- Well-tested operations
- Active maintenance

### For Webhook Handling
Use **github.com/wadeling/linear-webhook/api/linear**:
- Pre-defined webhook types
- Easy event parsing

---

## Resources

### Official Documentation
- [Linear API Docs](https://linear.app/developers)
- [GraphQL Getting Started](https://linear.app/developers/graphql)
- [OAuth 2.0 Authentication](https://linear.app/developers/oauth-2-0-authentication)
- [API Filtering](https://linear.app/developers/filtering)
- [GraphQL Schema (GitHub)](https://github.com/linear/linear/blob/master/packages/sdk/src/schema.graphql)

### Go Libraries
- [machinebox/graphql](https://github.com/machinebox/graphql)
- [hasura/go-graphql-client](https://github.com/hasura/go-graphql-client)
- [Khan/genqlient](https://github.com/Khan/genqlient)
- [shurcooL/graphql](https://github.com/shurcooL/graphql)

### Community Projects
- [geropl/linear-mcp-go](https://github.com/geropl/linear-mcp-go)
- [guillermo/linear](https://pkg.go.dev/github.com/guillermo/linear/linear-api)

### Tools
- [Apollo Studio - Linear API Schema](https://studio.apollographql.com/public/Linear-API/schema/reference?variant=current)
- [Linear API Guide (Rollout)](https://rollout.com/integration-guides/linear/sdk/step-by-step-guide-to-building-a-linear-api-integration-in-go)
