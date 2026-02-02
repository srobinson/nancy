# AI Agent Git Workflows: Parallel Execution Research

> Research compiled January 2025 - Modern git workflows for AI agents working in parallel

## Executive Summary

The rise of AI coding agents (Claude Code, GitHub Copilot, OpenAI Codex, Cursor) has created new challenges for version control. Traditional Git workflows assume single-developer, sequential work. AI agents operate differently - they're faster, can run in parallel, and generate larger diffs. This document explores emerging tools, patterns, and best practices for managing parallel AI agent development.

**Key Findings:**
- **Git worktrees** have become the de facto standard for running multiple AI agents in parallel
- **Jujutsu (jj)** is emerging as a Git-compatible alternative specifically suited for AI workflows
- **Stacked PRs** (via Graphite) help break AI-generated changes into reviewable chunks
- **GitButler** provides virtual branches enabling parallel work without worktrees
- Multiple orchestration tools are emerging: Code Conductor, Conductor (Mac), GitHub Agent HQ

---

## 1. Parallel Branch Management

### The Core Problem

Most AI agents assume exclusive access to the project directory. When multiple agents work simultaneously on different features, they interfere with each other's file changes, causing chaos.

### Solution: Git Worktrees

Git worktrees allow multiple working directories that share the same Git history but have independent file states.

```bash
# Create a worktree for an AI agent
git worktree add ../feature-auth -b feature/auth
git worktree add ../feature-dashboard -b feature/dashboard

# List active worktrees
git worktree list

# Each agent runs in its own directory
claude --cwd ../feature-auth
claude --cwd ../feature-dashboard

# Clean up when done
git worktree remove ../feature-auth
git worktree prune
```

**Why This Works:**
- Each worktree has its own independent file state
- All worktrees share the same Git history
- Changes committed in any worktree are immediately available to others
- Lightweight - shares .git directory (unlike full clones)

### Tools for Worktree Management

#### 1. CodeRabbit's git-worktree-runner (gtr)
- [GitHub Repository](https://github.com/coderabbitai/git-worktree-runner)
- Automates per-branch worktree creation
- Configuration copying and dependency installation
- Editor integration (Cursor, VS Code, Zed)
- AI tool support (Aider, Claude Code)
- Custom workflow scripts (.gtr-setup.sh)

#### 2. Conductor (Mac)
- [Website](https://www.conductor.build/)
- macOS app for running multiple Claude Code agents
- Each agent gets isolated workspace via git worktree
- Visual management of parallel agents
- Uses Claude Code SDK
- **Limitation:** Mac-only, Apple Silicon required

#### 3. Code Conductor
- [GitHub Repository](https://github.com/ryanmac/code-conductor)
- GitHub-native orchestration for AI coding agents
- Automatic conflict prevention via isolated worktrees
- Autonomous operation - agents claim tasks and ship
- Quick install: `bash <(curl -fsSL https://raw.githubusercontent.com/ryanmac/code-conductor/main/conductor-init.sh)`

### Best Practices for Worktree-Based Workflows

1. **Naming convention:** Use descriptive worktree names matching branch purpose
2. **Location:** Place worktrees in a `trees/` or `worktrees/` sibling directory
3. **Cleanup:** Regularly run `git worktree prune` to remove stale metadata
4. **Limit active worktrees:** Only maintain worktrees for active tasks
5. **Task isolation:** Ensure agents work on non-overlapping files when possible

---

## 2. Merge Conflict Prevention Strategies

### Prevention > Resolution

While AI can help resolve conflicts, preventing them is more efficient.

#### Architectural Strategies
- **Modular development:** Break features into smaller, independent components
- **File ownership:** Assign different areas of codebase to different agents
- **Frequent integration:** Regularly merge from main to stay updated
- **Small PRs:** AI-generated code especially benefits from smaller changes

#### Scope Boundaries for AI Agents
- Specify which files/directories are safe to modify
- Restrict permission to install new dependencies
- Require confirmation before changing configuration files
- Use CLAUDE.md or AGENTS.md to define boundaries

### AI-Powered Conflict Prevention Tools

| Tool | Description | Key Feature |
|------|-------------|-------------|
| [GitKraken](https://www.gitkraken.com/features/merge-conflict-resolution-tool) | Desktop Git client | Scans branches for potential conflicts before PR |
| [Graphite](https://graphite.com/guides/ai-code-merge-conflict-resolution) | AI code review platform | Predicts conflicts from historical patterns |
| [VS Code AI Merge](https://code.visualstudio.com/) | Editor integration | AI-assisted conflict resolution in editor |
| [Resolve.AI](https://marketplace.visualstudio.com/) | VS Code extension | Context-aware resolution suggestions |

### AI Conflict Resolution Approaches

1. **MergeBERT** - Transformer-based merge resolution (64-69% precision)
2. **rizzler** - LLM-powered merge driver for Git
3. **GitHub Copilot Pro+** - Can tackle complex merge conflicts automatically
4. **GitKraken AI** - Auto-resolve with explanations

### Key Insight

> "Simple conflicts: AI handles them very well. Complex conflicts: It provides suggestions, but human review remains essential."

---

## 3. Git Alternatives Designed for AI Development

### Jujutsu (jj) - The Emerging Standard

[GitHub Repository](https://github.com/jj-vcs/jj) | [Documentation](https://docs.jj-vcs.dev/latest/)

Jujutsu is a modern, Git-compatible VCS developed at Google that's gaining traction for AI workflows.

#### Why Jujutsu for AI Agents

1. **Working-copy-as-a-commit:** Changes are recorded automatically. No staging area complexity.
2. **First-class conflicts:** Conflicts are recorded, not blocking. Agents can continue working.
3. **Operation log & undo:** Every operation is recorded and reversible.
4. **Automatic rebasing:** When you modify a commit, descendants are auto-rebased.
5. **Branchless model:** Anonymous branching reduces naming overhead.

#### AI-Specific Benefits

From [Ian Bull's analysis](https://ianbull.com/posts/jj-vibes):
> "Traditional Git workflows were not designed for this. Jujutsu, with its flexible history model, cheap branching, and rewrite-friendly design, turns out to be an ideal foundation for an AI-native software workflow."

Mitchell Hashimoto's workflow:
> "I'll just be like, snapshot at this point, and then continue... In Jujutsu, it's the default behavior."

#### agentic-jujutsu

[NPM Package](https://www.npmjs.com/package/agentic-jujutsu) | [GitHub](https://github.com/ruvnet/agentic-flow/tree/main/packages/agentic-jujutsu)

A wrapper designed for multi-agent version control:
- **Lock-free concurrency:** 10-100x faster parallel operations
- **MCP Protocol integration:** AI agents call version control directly
- **Pattern learning:** System learns from past operations
- **87% automatic conflict resolution** (claimed)
- **Rust/WASM library** for universal runtime support

```bash
npm install agentic-jujutsu
```

### GitButler - Virtual Branches

[GitHub Repository](https://github.com/gitbutlerapp/gitbutler) | [Documentation](https://docs.gitbutler.com/)

GitButler rethinks Git with "virtual branches" - work on multiple features simultaneously in the same directory.

#### Key Features

- **Virtual branches:** Group uncommitted changes into separate logical branches
- **AI commit messages:** Auto-generate commit messages from changes
- **Stacked branches:** Create ordered stacks where each branch depends on the previous
- **Agents Tab:** Brings Claude Code directly into Git workflow (2025 feature)
- **Free and open-source**

#### Virtual vs Stacked Branches

| Virtual Branches | Stacked Branches |
|------------------|------------------|
| Independent from each other | Depend on previous branches |
| Parallel, unrelated work | Sequential, dependent changes |
| No ordering | Ordered stack |
| Separate PRs | Stacked PRs |

From GitButler docs:
> "The two features are not mutually exclusive but rather complementary."

---

## 4. Stacked PRs and Trunk-Based Development

### Why Stacked PRs Matter for AI

AI agents generate larger diffs than humans. Studies show only 24% of PRs over 1000 lines receive review comments. Stacking breaks large changes into reviewable chunks.

### Graphite - The Stacked PR Standard

[Website](https://graphite.com/) | [Docs](https://graphite.com/docs/gt-mcp)

Graphite has become the standard for stacked PRs, now with AI-native features.

#### Results from Graphite Users
- 1.3x more PRs in flight (concurrent work capacity)
- ~10 hours/week saved waiting to merge
- 26% more PRs merged
- 20% more code shipped
- 8% smaller median PR size

#### Graphite MCP Server for AI Agents

The GT MCP allows AI agents to automatically create stacked PRs:

```bash
# Install Graphite CLI (v1.6.7+)
npm install -g @withgraphite/graphite-cli

# Configure MCP in Claude Code
# The MCP server is built into the CLI
```

Benefits:
- AI learns to break changes into logical stacks
- Each PR is scoped, testable, and reviewable
- Mimics senior engineer workflow
- 30-45 minutes saved per complex task

From a Graphite user:
> "I Claude Coded about 200 lines of JS and then really wanted PRs for two things and a draft for the third. I one-shotted it all with gt mcp, and it saved me about 30-45 minutes."

### Trunk-Based Development with AI

Trunk-based development (TBD) pairs well with AI agents when combined with:

1. **Short-lived feature branches:** AI completes work quickly anyway
2. **Feature flags:** Merge incomplete work safely
3. **Stacked PRs:** Break large AI changes into trunk-mergeable chunks
4. **Continuous integration:** Catch AI-generated issues early

---

## 5. Multiple AI Agents Creating Branches/PRs Concurrently

### GitHub Copilot Coding Agent

[Documentation](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)

GitHub's native approach to concurrent AI agents:
- Assign issues to Copilot
- Agent creates PR with empty commit immediately
- Works in GitHub Actions environment (cloud)
- Results in ready-to-review PRs

#### GitHub Agent HQ / Mission Control

[GitHub Blog](https://github.blog/ai-and-ml/github-copilot/how-to-orchestrate-agents-using-mission-control/)

New features for managing multiple concurrent agents:
- Unified interface for multiple tasks
- Real-time session logs
- Mid-run steering (pause, refine, restart)
- Cross-repo task assignment

**Key consideration:**
> "When assigning multiple tasks from the same repo, consider overlap. Agents working in parallel can create merge conflicts if they touch the same files."

### OpenAI Codex Parallel Tasks

[Codex Cloud](https://developers.openai.com/codex/cloud/)

- Work on multiple tasks in background
- Cloud-based, isolated environments
- GitHub integration for repo/branch specification
- Queue multiple changes in parallel

**Workflow recommendation from Alex Embiricos (OpenAI):**
1. Create worktrees for conflicting tasks: "create two new worktrees off main"
2. Codex executes git worktree add commands
3. Each task runs in isolated branch/directory
4. Review, test, merge independently

### Concurrency Best Practices

#### Soft Locks Pattern
```
- Soft locks on PRs and issues
- Only one agent writes at a time
- Others can read/summarize
- Prevents "agent pileups"
```

#### Capacity Limits
From production testing:
- **Optimal:** 2 tasks per reviewer
- **Problematic:** 4+ tasks (error rates jump 1.8% -> 4.6%)
- **Result with limits:** 48-task backlog cleared in 27 minutes, 98.7% success

#### Golden Rules

1. **AI agents can propose code, but never own it**
2. **AI-generated PRs require stricter review thresholds**
3. **Tag AI-generated code for traceability**
4. **Humans resolve agent conflicts, not other agents**

---

## 6. Recommendations for Nancy Parallel Execution

Based on this research, here are specific recommendations for Nancy's multi-agent orchestration:

### Architecture Recommendations

#### 1. Git Worktree Foundation
```bash
# Nancy should create isolated worktrees per agent
nancy/
  main-workspace/           # Primary workspace
  trees/
    agent-1-feature-auth/   # Agent 1's workspace
    agent-2-feature-api/    # Agent 2's workspace
    agent-3-bugfix-123/     # Agent 3's workspace
```

#### 2. Task Isolation Strategy
```yaml
# Assign agents to non-overlapping areas
agent_1:
  scope: ["src/auth/**", "tests/auth/**"]
  forbidden: ["src/core/**"]

agent_2:
  scope: ["src/api/**", "tests/api/**"]
  forbidden: ["src/auth/**"]
```

#### 3. Consider Jujutsu Integration
For advanced parallel workflows:
- First-class conflict handling
- Automatic snapshots during AI iteration
- Better undo/redo for AI experimentation
- Operation logs for debugging

### Conflict Prevention for Nancy

1. **Pre-flight check:** Before assigning task, analyze which files will be touched
2. **Scope boundaries:** Define per-agent allowed directories in task spec
3. **Lock file tracking:** Track which files each agent is modifying
4. **Sequential fallback:** If overlap detected, queue instead of parallel

### PR Strategy

1. **Integrate Graphite MCP:** Enable stacked PR creation
2. **PR size limits:** If diff > 500 lines, require stacking
3. **Labeling:** Tag PRs with agent ID and task ID
4. **Review requirements:** AI PRs need human approval + CI pass

### Tooling Integration

| Tool | Purpose | Priority |
|------|---------|----------|
| Git Worktrees | Agent isolation | High |
| Graphite MCP | Stacked PRs | High |
| gtr (git-worktree-runner) | Worktree automation | Medium |
| Jujutsu | Experimental VCS | Low (evaluate) |
| agentic-jujutsu | Multi-agent VCS | Low (evaluate) |

### Monitoring and Observability

Track metrics:
- Conflict rate per agent pair
- Time to merge per agent
- PR review time for AI vs human code
- Rollback rate for AI-generated changes

---

## Sources

### Git Worktrees for AI Agents
- [Nx Blog: How Git Worktrees Changed My AI Agent Workflow](https://nx.dev/blog/git-worktrees-ai-agents)
- [Medium: Parallel Workflows with Git Worktrees](https://medium.com/@dennis.somerville/parallel-workflows-git-worktrees-and-the-art-of-managing-multiple-ai-agents-6fa3dc5eec1d)
- [Agent Interviews: Parallel AI Coding](https://docs.agentinterviews.com/blog/parallel-ai-coding-with-gitworktrees/)
- [Nick Mitchinson: Git Worktrees for AI Agents](https://www.nrmitchi.com/2025/10/using-git-worktrees-for-multi-feature-development-with-ai-agents/)

### Jujutsu (jj)
- [GitHub: jj-vcs/jj](https://github.com/jj-vcs/jj)
- [Ian Bull: Towards an AI-Native Development Workflow](https://ianbull.com/posts/jj-vibes)
- [Alpha Insights: Use Jujutsu, Not Git](https://slavakurilyak.com/posts/use-jujutsu-not-git)
- [Chris Krycho: jj init](https://v5.chriskrycho.com/essays/jj-init)

### GitButler
- [GitHub: gitbutlerapp/gitbutler](https://github.com/gitbutlerapp/gitbutler)
- [GitButler Docs](https://docs.gitbutler.com/)
- [GitButler Blog: Claude Code Tab](https://blog.gitbutler.com/agents-tab)

### Graphite and Stacked PRs
- [Graphite: Stacked PRs](https://graphite.com/blog/stacked-prs)
- [Graphite MCP Server](https://graphite.com/docs/gt-mcp)
- [Graphite: AI Merge Conflict Resolution](https://graphite.com/guides/ai-code-merge-conflict-resolution)

### Multi-Agent Orchestration
- [GitHub: Code Conductor](https://github.com/ryanmac/code-conductor)
- [Conductor.build](https://www.conductor.build/)
- [CodeRabbit: git-worktree-runner](https://github.com/coderabbitai/git-worktree-runner)
- [GitHub Blog: Agent HQ](https://github.blog/news-insights/company-news/welcome-home-agents/)
- [GitHub Blog: Mission Control](https://github.blog/ai-and-ml/github-copilot/how-to-orchestrate-agents-using-mission-control/)

### OpenAI Codex
- [OpenAI: Introducing Codex](https://openai.com/index/introducing-codex/)
- [ChatPRD: Advanced Codex Workflows](https://www.chatprd.ai/how-i-ai/advanced-codex-workflows-with-openai-alex-embiricos)
- [Codex Developers Docs](https://developers.openai.com/codex/)

### agentic-jujutsu
- [NPM: agentic-jujutsu](https://www.npmjs.com/package/agentic-jujutsu)
- [GitHub: ruvnet/agentic-flow](https://github.com/ruvnet/agentic-flow)

### AI Conflict Resolution
- [GitKraken Merge Tool](https://www.gitkraken.com/solutions/gitkraken-merge-tool)
- [VS Code AI Merge](https://www.infoworld.com/article/4075822/visual-studio-code-taps-ai-for-merge-conflict-resolution.html)
- [Anthropic: Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
