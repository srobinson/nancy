# Bubble Tea Best Practices 2026

A practical reference for building production-quality TUI applications with [charmbracelet/bubbletea](https://github.com/charmbracelet/bubbletea).

**Current Stable:** v1.3.x | **Upcoming:** v2.0.0 (RC stage)

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Architecture (MVU Pattern)](#core-architecture-mvu-pattern)
3. [Component Organization](#component-organization)
4. [State Management Patterns](#state-management-patterns)
5. [Commands and Async Operations](#commands-and-async-operations)
6. [Testing Approaches](#testing-approaches)
7. [Performance Considerations](#performance-considerations)
8. [v2 Migration Notes](#v2-migration-notes)

---

## Project Structure

### Recommended Layout

Based on the [official bubbletea-app-template](https://github.com/charmbracelet/bubbletea-app-template) and community patterns:

```
myapp/
├── .github/
│   └── workflows/
│       ├── build.yml
│       └── release.yml
├── internal/
│   ├── tui/
│   │   ├── model.go          # Root model and program setup
│   │   ├── update.go         # Message handling logic
│   │   ├── view.go           # Rendering logic
│   │   ├── keys.go           # Keybindings definitions
│   │   ├── styles.go         # Lipgloss style definitions
│   │   └── components/       # Reusable UI components
│   │       ├── sidebar/
│   │       ├── header/
│   │       └── statusbar/
│   ├── commands/             # tea.Cmd wrappers for I/O
│   │   ├── api.go
│   │   └── filesystem.go
│   └── storage/              # Data layer
├── cmd/
│   └── myapp/
│       └── main.go           # Entry point
├── .golangci.yml
├── .goreleaser.yaml
├── go.mod
└── go.sum
```

### Simple Applications

For smaller projects, a flat structure works well:

```
myapp/
├── main.go                   # Contains model, update, view
├── commands.go               # tea.Cmd functions
├── styles.go                 # Lipgloss styles
├── go.mod
└── go.sum
```

### Key Dependencies (2025-2026)

```go
require (
    github.com/charmbracelet/bubbletea v1.3.4
    github.com/charmbracelet/bubbles  v0.21.0
    github.com/charmbracelet/lipgloss v1.1.1
    github.com/charmbracelet/glamour  v0.8.0   // Markdown rendering
    github.com/charmbracelet/harmonica v0.2.0  // Animations
)
```

---

## Core Architecture (MVU Pattern)

Bubble Tea uses The Elm Architecture with three core methods:

### The Model Interface

```go
type Model interface {
    // Init returns the initial command (or nil)
    Init() tea.Cmd

    // Update handles messages and returns updated model + command
    Update(tea.Msg) (tea.Model, tea.Cmd)

    // View renders the UI as a string
    View() string
}
```

### Basic Implementation

```go
package main

import (
    "fmt"
    tea "github.com/charmbracelet/bubbletea"
)

type model struct {
    cursor   int
    choices  []string
    selected map[int]struct{}
}

func initialModel() model {
    return model{
        choices:  []string{"Buy carrots", "Buy celery", "Buy kohlrabi"},
        selected: make(map[int]struct{}),
    }
}

func (m model) Init() tea.Cmd {
    return nil // No initial command
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+c", "q":
            return m, tea.Quit
        case "up", "k":
            if m.cursor > 0 {
                m.cursor--
            }
        case "down", "j":
            if m.cursor < len(m.choices)-1 {
                m.cursor++
            }
        case "enter", " ":
            if _, ok := m.selected[m.cursor]; ok {
                delete(m.selected, m.cursor)
            } else {
                m.selected[m.cursor] = struct{}{}
            }
        }
    }
    return m, nil
}

func (m model) View() string {
    s := "What should we buy at the market?\n\n"
    for i, choice := range m.choices {
        cursor := " "
        if m.cursor == i {
            cursor = ">"
        }
        checked := " "
        if _, ok := m.selected[i]; ok {
            checked = "x"
        }
        s += fmt.Sprintf("%s [%s] %s\n", cursor, checked, choice)
    }
    s += "\nPress q to quit.\n"
    return s
}

func main() {
    p := tea.NewProgram(initialModel())
    if _, err := p.Run(); err != nil {
        fmt.Printf("Error: %v", err)
    }
}
```

---

## Component Organization

### Embedding Bubbles Components

```go
import (
    "github.com/charmbracelet/bubbles/list"
    "github.com/charmbracelet/bubbles/textinput"
    "github.com/charmbracelet/bubbles/viewport"
    tea "github.com/charmbracelet/bubbletea"
)

type model struct {
    list      list.Model
    input     textinput.Model
    viewport  viewport.Model
    ready     bool  // For lazy initialization
    width     int
    height    int
}
```

### Keybindings with bubbles/key

```go
import "github.com/charmbracelet/bubbles/key"

type keyMap struct {
    Up     key.Binding
    Down   key.Binding
    Select key.Binding
    Quit   key.Binding
}

func newKeyMap() keyMap {
    return keyMap{
        Up: key.NewBinding(
            key.WithKeys("k", "up"),
            key.WithHelp("up/k", "move up"),
        ),
        Down: key.NewBinding(
            key.WithKeys("j", "down"),
            key.WithHelp("down/j", "move down"),
        ),
        Select: key.NewBinding(
            key.WithKeys("enter", " "),
            key.WithHelp("enter/space", "select"),
        ),
        Quit: key.NewBinding(
            key.WithKeys("q", "ctrl+c"),
            key.WithHelp("q", "quit"),
        ),
    }
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch {
        case key.Matches(msg, m.keys.Quit):
            return m, tea.Quit
        case key.Matches(msg, m.keys.Up):
            m.cursor--
        case key.Matches(msg, m.keys.Down):
            m.cursor++
        }
    }
    return m, nil
}
```

### Style Definitions with Lipgloss

```go
// styles.go
package tui

import "github.com/charmbracelet/lipgloss"

var (
    subtle    = lipgloss.AdaptiveColor{Light: "#D9DCCF", Dark: "#383838"}
    highlight = lipgloss.AdaptiveColor{Light: "#874BFD", Dark: "#7D56F4"}

    titleStyle = lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("#FAFAFA")).
        Background(highlight).
        Padding(0, 1)

    listItemStyle = lipgloss.NewStyle().
        PaddingLeft(2)

    selectedItemStyle = lipgloss.NewStyle().
        PaddingLeft(2).
        Foreground(highlight)

    statusBarStyle = lipgloss.NewStyle().
        Background(subtle).
        Padding(0, 1)
)
```

---

## State Management Patterns

### Pattern 1: Top-Down Composition (Recommended for Most Apps)

```go
type sessionState int

const (
    listView sessionState = iota
    detailView
    editView
)

type model struct {
    state    sessionState
    list     list.Model
    detail   detailModel
    editor   editorModel
    width    int
    height   int
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd

    // Handle global messages first
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
    case tea.KeyMsg:
        if msg.String() == "ctrl+c" {
            return m, tea.Quit
        }
    }

    // Delegate to active view
    switch m.state {
    case listView:
        m.list, cmd = m.list.Update(msg)
    case detailView:
        m.detail, cmd = m.detail.Update(msg)
    case editView:
        m.editor, cmd = m.editor.Update(msg)
    }

    return m, cmd
}

func (m model) View() string {
    switch m.state {
    case listView:
        return m.list.View()
    case detailView:
        return m.detail.View()
    case editView:
        return m.editor.View()
    default:
        return ""
    }
}
```

### Pattern 2: Lazy Initialization (For Size-Dependent Components)

```go
type model struct {
    viewport viewport.Model
    ready    bool
    content  string
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        if !m.ready {
            // Initialize viewport only after we know dimensions
            m.viewport = viewport.New(msg.Width, msg.Height-4)
            m.viewport.SetContent(m.content)
            m.ready = true
        } else {
            m.viewport.Width = msg.Width
            m.viewport.Height = msg.Height - 4
        }
    }

    if m.ready {
        var cmd tea.Cmd
        m.viewport, cmd = m.viewport.Update(msg)
        return m, cmd
    }
    return m, nil
}

func (m model) View() string {
    if !m.ready {
        return "Loading..."
    }
    return m.viewport.View()
}
```

### Pattern 3: Model Stack (For Complex Navigation)

For apps with many independent screens, consider a stack-based approach:

```go
type stack struct {
    models []tea.Model
}

func (s *stack) Push(m tea.Model) tea.Cmd {
    s.models = append(s.models, m)
    return m.Init()
}

func (s *stack) Pop() {
    if len(s.models) > 1 {
        s.models = s.models[:len(s.models)-1]
    }
}

func (s *stack) Current() tea.Model {
    return s.models[len(s.models)-1]
}
```

---

## Commands and Async Operations

### Basic Command Pattern

```go
// Commands are functions that return a Msg
type dataLoadedMsg struct {
    data string
    err  error
}

func loadDataCmd(url string) tea.Cmd {
    return func() tea.Msg {
        resp, err := http.Get(url)
        if err != nil {
            return dataLoadedMsg{err: err}
        }
        defer resp.Body.Close()

        body, err := io.ReadAll(resp.Body)
        return dataLoadedMsg{data: string(body), err: err}
    }
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case dataLoadedMsg:
        if msg.err != nil {
            m.errMsg = msg.err.Error()
        } else {
            m.data = msg.data
        }
    }
    return m, nil
}
```

### Concurrent Commands with tea.Batch

```go
func (m model) Init() tea.Cmd {
    return tea.Batch(
        loadUsersCmd(),
        loadSettingsCmd(),
        loadRecentItemsCmd(),
    )
}
```

### Sequential Commands with tea.Sequence

```go
// Execute commands in order
func initSequence() tea.Cmd {
    return tea.Sequence(
        connectToDatabase,
        loadSchema,
        fetchInitialData,
    )
}
```

### Tick/Timer Commands

```go
type tickMsg time.Time

func tickCmd() tea.Cmd {
    return tea.Tick(time.Second, func(t time.Time) tea.Msg {
        return tickMsg(t)
    })
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tickMsg:
        m.elapsed++
        return m, tickCmd() // Schedule next tick
    }
    return m, nil
}
```

### External Process Execution

```go
type editorFinishedMsg struct{ err error }

func openEditorCmd(filename string) tea.Cmd {
    editor := os.Getenv("EDITOR")
    if editor == "" {
        editor = "vim"
    }
    c := exec.Command(editor, filename)
    return tea.ExecProcess(c, func(err error) tea.Msg {
        return editorFinishedMsg{err}
    })
}
```

---

## Testing Approaches

### Setup: teatest Package

```go
import (
    "testing"
    "github.com/charmbracelet/x/exp/teatest"
    "github.com/charmbracelet/lipgloss"
    "github.com/muesli/termenv"
)

// Force consistent colors across environments
func init() {
    lipgloss.SetColorProfile(termenv.Ascii)
}
```

### Golden File Testing

```go
func TestAppOutput(t *testing.T) {
    m := initialModel()
    tm := teatest.NewTestModel(t, m,
        teatest.WithInitialTermSize(80, 24),
    )

    // Wait for program to finish
    tm.WaitFinished(t, teatest.WithFinalTimeout(time.Second*5))

    // Get final output
    out, err := io.ReadAll(tm.FinalOutput(t))
    if err != nil {
        t.Fatal(err)
    }

    // Compare against golden file
    teatest.RequireEqualOutput(t, out)
}
```

Generate/update golden files:

```bash
go test -v ./... -update
```

### Testing User Interactions

```go
func TestQuitOnQ(t *testing.T) {
    m := initialModel()
    tm := teatest.NewTestModel(t, m,
        teatest.WithInitialTermSize(80, 24),
    )

    // Simulate key press
    tm.Send(tea.KeyMsg{
        Type:  tea.KeyRunes,
        Runes: []rune("q"),
    })

    tm.WaitFinished(t, teatest.WithFinalTimeout(time.Second))

    // Verify final model state
    fm := tm.FinalModel(t)
    if model, ok := fm.(model); ok {
        // Assert expected state
    }
}
```

### Testing Intermediate States

```go
func TestLoadingIndicator(t *testing.T) {
    tm := teatest.NewTestModel(t, initialModel(),
        teatest.WithInitialTermSize(80, 24),
    )

    // Wait for specific output
    teatest.WaitFor(t, tm.Output(),
        func(bts []byte) bool {
            return bytes.Contains(bts, []byte("Loading..."))
        },
        teatest.WithCheckInterval(100*time.Millisecond),
        teatest.WithDuration(3*time.Second),
    )
}
```

### Git Configuration for Golden Files

Add to `.gitattributes`:

```
*.golden -text
testdata/** -text
```

---

## Performance Considerations

### Keep Update() and View() Fast

```go
// BAD: Expensive operation in Update
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.data = expensiveComputation() // Blocks event loop!
    return m, nil
}

// GOOD: Offload to command
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    return m, computeCmd() // Runs in goroutine
}

func computeCmd() tea.Cmd {
    return func() tea.Msg {
        result := expensiveComputation()
        return computeResultMsg{result}
    }
}
```

### Use strings.Builder for View

```go
// BAD: String concatenation creates many allocations
func (m model) View() string {
    s := ""
    for _, item := range m.items {
        s += item.String() + "\n"
    }
    return s
}

// GOOD: strings.Builder is more efficient
func (m model) View() string {
    var b strings.Builder
    for _, item := range m.items {
        b.WriteString(item.String())
        b.WriteString("\n")
    }
    return b.String()
}
```

### Dynamic Dimension Calculation

```go
// BAD: Hardcoded heights break when styles change
func (m model) View() string {
    headerHeight := 3 // What if border changes?
    contentHeight := m.height - headerHeight - 2
    // ...
}

// GOOD: Measure rendered content
func (m model) View() string {
    header := m.renderHeader()
    footer := m.renderFooter()

    headerHeight := lipgloss.Height(header)
    footerHeight := lipgloss.Height(footer)
    contentHeight := m.height - headerHeight - footerHeight

    m.viewport.Height = contentHeight
    // ...
}
```

### Handle Window Size Messages

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height

        // Update child components
        m.list.SetSize(msg.Width, msg.Height-4)
        m.viewport.Width = msg.Width
        m.viewport.Height = msg.Height - 6
    }
    return m, nil
}
```

### Message Ordering Awareness

Messages from concurrent commands may arrive out of order:

```go
// Commands started together may complete in any order
func (m model) Init() tea.Cmd {
    return tea.Batch(
        fetchUserCmd(),     // May complete second
        fetchSettingsCmd(), // May complete first
    )
}

// Use tea.Sequence if order matters
func (m model) Init() tea.Cmd {
    return tea.Sequence(
        fetchUserCmd(),     // Always completes first
        fetchSettingsCmd(), // Starts after user loaded
    )
}
```

---

## v2 Migration Notes

Bubble Tea v2 is in RC stage (as of late 2025). Key changes to prepare for:

### Import Path Change

```go
// v1
import tea "github.com/charmbracelet/bubbletea"

// v2 (RC1+)
import tea "charm.land/bubbletea/v2"
```

### Enhanced Keyboard Handling

```go
// v2 supports advanced key detection
tea.WithKeyReleases()           // Detect key releases
tea.WithUniformKeyLayout()      // Consistent key reporting
tea.RequestKeyDisambiguation()  // Disambiguated events
```

### Improved Mouse API

```go
// v1: Single MouseMsg type
case tea.MouseMsg:
    // Handle all mouse events

// v2: Specific message types
case tea.MouseClickMsg:
    // Handle clicks
case tea.MouseReleaseMsg:
    // Handle releases
case tea.MouseWheelMsg:
    // Handle scroll
case tea.MouseMotionMsg:
    // Handle movement
```

### Declarative View API (v2)

The View API becomes more declarative with a single source of truth for view properties, eliminating race conditions and improving performance.

### Synchronized Output (Mode 2026)

v2 includes support for synchronized terminal output, reducing flickering and improving rendering bandwidth.

---

## Additional Resources

- [Official Bubble Tea Repository](https://github.com/charmbracelet/bubbletea)
- [Bubble Tea Tutorials](https://github.com/charmbracelet/bubbletea/tree/main/tutorials)
- [Bubbles Component Library](https://github.com/charmbracelet/bubbles)
- [Lip Gloss Styling](https://github.com/charmbracelet/lipgloss)
- [Official App Template](https://github.com/charmbracelet/bubbletea-app-template)
- [teatest Package](https://github.com/charmbracelet/x/tree/main/exp/teatest)
- [Tips for Building Bubble Tea Programs](https://leg100.github.io/en/posts/building-bubbletea-programs/)
- [Writing Bubble Tea Tests](https://carlosbecker.com/posts/teatest/)
- [Managing Nested Models](https://donderom.com/posts/managing-nested-models-with-bubble-tea/)
