# Fuzzy Search and Command Palette Patterns in Bubble Tea

Research document covering fuzzy finding, search interfaces, and command palette patterns for Bubble Tea TUI applications.

## Table of Contents

1. [Overview](#overview)
2. [Fuzzy Matching Libraries](#fuzzy-matching-libraries)
3. [Bubbles TextInput Component](#bubbles-textinput-component)
4. [List Component with Filtering](#list-component-with-filtering)
5. [Keyboard Navigation Patterns](#keyboard-navigation-patterns)
6. [Styling Search Results with Lipgloss](#styling-search-results-with-lipgloss)
7. [Command Palette Implementation](#command-palette-implementation)
8. [Complete Example: Command Palette](#complete-example-command-palette)

---

## Overview

Building fuzzy search interfaces in Bubble Tea involves combining several components:
- **Fuzzy matching library** for scoring and matching strings
- **TextInput bubble** for capturing search queries
- **List bubble** or custom list for displaying results
- **Lipgloss** for styling matched characters and search UI
- **Keyboard handling** for navigation (up/down/enter/escape)

---

## Fuzzy Matching Libraries

### sahilm/fuzzy (Recommended)

The `github.com/sahilm/fuzzy` library is optimized for filenames and code symbols, similar to VS Code and Sublime Text.

**Installation:**
```bash
go get github.com/sahilm/fuzzy
```

**Key Features:**
- Returns match positions for highlighting
- Scores matches by quality
- External dependency-free
- ~30ms for 60K files from Linux kernel

**Basic Usage:**
```go
package main

import (
    "fmt"
    "github.com/sahilm/fuzzy"
)

func main() {
    pattern := "cmd"
    data := []string{
        "command_palette.go",
        "commands.go",
        "README.md",
        "config.yaml",
    }

    matches := fuzzy.Find(pattern, data)

    for _, match := range matches {
        fmt.Printf("Match: %s (score: %d)\n", match.Str, match.Score)
        fmt.Printf("Matched indices: %v\n", match.MatchedIndexes)
    }
}
```

**The Match struct:**
```go
type Match struct {
    Str            string  // The matched string
    Index          int     // Index in original slice
    MatchedIndexes []int   // Positions of matched characters (for highlighting)
    Score          int     // Quality score (higher = better match)
}
```

**Highlighting Matched Characters:**
```go
func highlightMatch(match fuzzy.Match) string {
    const bold = "\033[1m%s\033[0m"
    var result strings.Builder

    for i := 0; i < len(match.Str); i++ {
        if contains(i, match.MatchedIndexes) {
            result.WriteString(fmt.Sprintf(bold, string(match.Str[i])))
        } else {
            result.WriteString(string(match.Str[i]))
        }
    }
    return result.String()
}

func contains(needle int, haystack []int) bool {
    for _, i := range haystack {
        if needle == i {
            return true
        }
    }
    return false
}
```

### go-fuzzyfinder (Full TUI)

The `github.com/ktr0731/go-fuzzyfinder` provides a complete fzf-like TUI.

**Installation:**
```bash
go get github.com/ktr0731/go-fuzzyfinder
```

**Usage with Preview Window:**
```go
package main

import (
    "fmt"
    "log"
    "github.com/ktr0731/go-fuzzyfinder"
)

type Command struct {
    Name        string
    Description string
    Shortcut    string
}

var commands = []Command{
    {"Open File", "Open a file in the editor", "Cmd+O"},
    {"Save File", "Save the current file", "Cmd+S"},
    {"Find", "Find text in file", "Cmd+F"},
    {"Go to Line", "Jump to a specific line", "Cmd+G"},
}

func main() {
    idx, err := fuzzyfinder.Find(
        commands,
        func(i int) string {
            return commands[i].Name
        },
        fuzzyfinder.WithPreviewWindow(func(i, w, h int) string {
            if i == -1 {
                return ""
            }
            return fmt.Sprintf("%s\n\n%s\n\nShortcut: %s",
                commands[i].Name,
                commands[i].Description,
                commands[i].Shortcut)
        }),
    )
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Selected: %s\n", commands[idx].Name)
}
```

**Multi-Select with FindMulti:**
```go
idxs, err := fuzzyfinder.FindMulti(
    items,
    func(i int) string {
        return items[i].Name
    },
    fuzzyfinder.WithMode(fuzzyfinder.ModeCaseSensitive),
)
```

**Matching Modes:**
- `ModeSmart` (default): Case-insensitive until uppercase is typed
- `ModeCaseSensitive`: Always case-sensitive
- `ModeCaseInsensitive`: Always case-insensitive

---

## Bubbles TextInput Component

The `textinput` bubble provides a text input field for search bars.

**Basic TextInput:**
```go
package main

import (
    "fmt"
    "github.com/charmbracelet/bubbles/textinput"
    tea "github.com/charmbracelet/bubbletea"
)

type model struct {
    textInput textinput.Model
    query     string
}

func initialModel() model {
    ti := textinput.New()
    ti.Placeholder = "Search commands..."
    ti.Focus()
    ti.CharLimit = 100
    ti.Width = 40
    return model{textInput: ti}
}

func (m model) Init() tea.Cmd {
    return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd

    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+c", "esc":
            return m, tea.Quit
        case "enter":
            m.query = m.textInput.Value()
            return m, tea.Quit
        }
    }

    m.textInput, cmd = m.textInput.Update(msg)
    return m, cmd
}

func (m model) View() string {
    return fmt.Sprintf(
        "Search:\n%s\n\n(esc to quit)",
        m.textInput.View(),
    )
}

func main() {
    p := tea.NewProgram(initialModel())
    if _, err := p.Run(); err != nil {
        fmt.Printf("Error: %v", err)
    }
}
```

**TextInput Configuration Options:**
```go
ti := textinput.New()
ti.Placeholder = "Type to search..."   // Placeholder text
ti.Focus()                              // Give focus
ti.CharLimit = 156                      // Max characters
ti.Width = 50                           // Display width
ti.Prompt = "> "                        // Prompt prefix
ti.EchoMode = textinput.EchoNormal      // Normal/Password/None
ti.Validate = func(s string) error {    // Optional validation
    if len(s) > 100 {
        return fmt.Errorf("too long")
    }
    return nil
}
```

---

## List Component with Filtering

The bubbles `list` component has built-in fuzzy filtering.

**Basic List with Filtering:**
```go
package main

import (
    "fmt"
    "github.com/charmbracelet/bubbles/list"
    tea "github.com/charmbracelet/bubbletea"
)

type item struct {
    title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title } // Used for filtering

type model struct {
    list list.Model
}

func (m model) Init() tea.Cmd {
    return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "ctrl+c" {
            return m, tea.Quit
        }
    case tea.WindowSizeMsg:
        m.list.SetWidth(msg.Width)
        m.list.SetHeight(msg.Height)
        return m, nil
    }

    var cmd tea.Cmd
    m.list, cmd = m.list.Update(msg)
    return m, cmd
}

func (m model) View() string {
    return m.list.View()
}

func main() {
    items := []list.Item{
        item{title: "Open File", desc: "Open a file in editor"},
        item{title: "Save File", desc: "Save current file"},
        item{title: "Close Tab", desc: "Close the current tab"},
        item{title: "Find", desc: "Search in file"},
        item{title: "Replace", desc: "Find and replace"},
    }

    l := list.New(items, list.NewDefaultDelegate(), 0, 0)
    l.Title = "Command Palette"
    l.SetFilteringEnabled(true)
    l.SetShowStatusBar(false)
    l.SetShowTitle(true)

    p := tea.NewProgram(model{list: l}, tea.WithAltScreen())
    if _, err := p.Run(); err != nil {
        fmt.Printf("Error: %v", err)
    }
}
```

**Programmatic Filtering:**
```go
// Set filter text programmatically
m.list.SetFilterText("search term")

// Get current filter value
currentFilter := m.list.FilterValue()

// Control filter state
m.list.SetFilterState(list.FilterApplied)

// Available filter states:
// list.Unfiltered
// list.Filtering
// list.FilterApplied
```

**Custom Item Interface:**
```go
// Item interface - required for all list items
type Item interface {
    FilterValue() string
}

// DefaultItem interface - for use with DefaultDelegate
type DefaultItem interface {
    Item
    Title() string
    Description() string
}
```

---

## Keyboard Navigation Patterns

**Standard Navigation Keys:**
```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        // Exit/Cancel
        case "ctrl+c", "esc":
            return m, tea.Quit

        // Navigation (vim-style and arrow keys)
        case "up", "k":
            if m.cursor > 0 {
                m.cursor--
            }
        case "down", "j":
            if m.cursor < len(m.items)-1 {
                m.cursor++
            }

        // Page navigation
        case "pgup", "ctrl+u":
            m.cursor -= m.pageSize
            if m.cursor < 0 {
                m.cursor = 0
            }
        case "pgdown", "ctrl+d":
            m.cursor += m.pageSize
            if m.cursor >= len(m.items) {
                m.cursor = len(m.items) - 1
            }

        // Jump to start/end
        case "home", "g":
            m.cursor = 0
        case "end", "G":
            m.cursor = len(m.items) - 1

        // Selection
        case "enter":
            m.selected = m.items[m.cursor]
            return m, tea.Quit

        // Tab for autocomplete
        case "tab":
            if len(m.filteredItems) == 1 {
                m.textInput.SetValue(m.filteredItems[0].Title())
            }
        }
    }
    return m, nil
}
```

**Key Type Checking (More Robust):**
```go
switch msg := msg.(type) {
case tea.KeyMsg:
    switch msg.Type {
    case tea.KeyEnter:
        // Handle enter
    case tea.KeyEsc:
        // Handle escape
    case tea.KeyUp:
        // Handle up arrow
    case tea.KeyDown:
        // Handle down arrow
    case tea.KeyCtrlC:
        return m, tea.Quit
    case tea.KeyRunes:
        // Handle typed characters
        switch string(msg.Runes) {
        case "j":
            // vim down
        case "k":
            // vim up
        }
    }
}
```

---

## Styling Search Results with Lipgloss

### Basic Styles for Command Palette

```go
package styles

import "github.com/charmbracelet/lipgloss"

var (
    // Container styles
    PaletteStyle = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color("62")).
        Padding(1, 2).
        Width(60)

    // Search input styles
    SearchPrompt = lipgloss.NewStyle().
        Foreground(lipgloss.Color("205")).
        Bold(true)

    SearchInput = lipgloss.NewStyle().
        Foreground(lipgloss.Color("255"))

    // Result item styles
    NormalItem = lipgloss.NewStyle().
        Foreground(lipgloss.Color("252")).
        PaddingLeft(2)

    SelectedItem = lipgloss.NewStyle().
        Foreground(lipgloss.Color("212")).
        Background(lipgloss.Color("236")).
        Bold(true).
        PaddingLeft(2)

    // Match highlight style
    MatchHighlight = lipgloss.NewStyle().
        Foreground(lipgloss.Color("212")).
        Bold(true)

    // Description style
    Description = lipgloss.NewStyle().
        Foreground(lipgloss.Color("240")).
        PaddingLeft(4)

    // Shortcut style
    Shortcut = lipgloss.NewStyle().
        Foreground(lipgloss.Color("241")).
        Align(lipgloss.Right)

    // Status bar
    StatusBar = lipgloss.NewStyle().
        Foreground(lipgloss.Color("241")).
        MarginTop(1)
)
```

### Highlighting Matched Characters with Lipgloss

```go
import (
    "github.com/charmbracelet/lipgloss"
    "github.com/sahilm/fuzzy"
)

var (
    normalStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
    highlightStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("212")).Bold(true)
)

// RenderMatchedString renders a string with matched characters highlighted
func RenderMatchedString(match fuzzy.Match) string {
    var result strings.Builder
    matchSet := make(map[int]bool)

    for _, idx := range match.MatchedIndexes {
        matchSet[idx] = true
    }

    for i, char := range match.Str {
        if matchSet[i] {
            result.WriteString(highlightStyle.Render(string(char)))
        } else {
            result.WriteString(normalStyle.Render(string(char)))
        }
    }

    return result.String()
}
```

### Using Lipgloss v2 StyleRanges (Latest)

```go
import "github.com/charmbracelet/lipgloss/v2"

func highlightWithRanges(text string, matchedIndexes []int) string {
    if len(matchedIndexes) == 0 {
        return text
    }

    highlightStyle := lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("#FF79C6"))

    // Convert individual indexes to ranges
    var ranges []lipgloss.Range
    for _, idx := range matchedIndexes {
        ranges = append(ranges, lipgloss.NewRange(idx, idx+1, highlightStyle))
    }

    return lipgloss.StyleRanges(text, ranges...)
}
```

### Adaptive Colors (Light/Dark Terminals)

```go
var (
    highlightColor = lipgloss.AdaptiveColor{
        Light: "#874BFD",  // Purple for light backgrounds
        Dark:  "#FF79C6",  // Pink for dark backgrounds
    }

    MatchHighlight = lipgloss.NewStyle().
        Foreground(highlightColor).
        Bold(true)
)
```

---

## Command Palette Implementation

### Model Structure

```go
type CommandPaletteModel struct {
    textInput     textinput.Model
    commands      []Command
    filtered      []fuzzy.Match
    cursor        int
    selected      *Command
    width         int
    height        int
    visible       bool
}

type Command struct {
    ID          string
    Name        string
    Description string
    Shortcut    string
    Action      func() tea.Cmd
}
```

### Filtering Logic

```go
func (m *CommandPaletteModel) filterCommands() {
    query := m.textInput.Value()

    if query == "" {
        // Show all commands when no query
        m.filtered = make([]fuzzy.Match, len(m.commands))
        for i, cmd := range m.commands {
            m.filtered[i] = fuzzy.Match{
                Str:   cmd.Name,
                Index: i,
            }
        }
        return
    }

    // Extract command names for fuzzy matching
    names := make([]string, len(m.commands))
    for i, cmd := range m.commands {
        names[i] = cmd.Name
    }

    m.filtered = fuzzy.Find(query, names)

    // Reset cursor if out of bounds
    if m.cursor >= len(m.filtered) {
        m.cursor = max(0, len(m.filtered)-1)
    }
}
```

### Rendering the Palette

```go
func (m CommandPaletteModel) View() string {
    if !m.visible {
        return ""
    }

    var b strings.Builder

    // Search input
    b.WriteString(SearchPrompt.Render("> "))
    b.WriteString(m.textInput.View())
    b.WriteString("\n\n")

    // Results
    maxVisible := min(10, len(m.filtered))
    for i := 0; i < maxVisible; i++ {
        match := m.filtered[i]
        cmd := m.commands[match.Index]

        // Render item with highlights
        itemText := RenderMatchedString(match)

        // Add description
        if cmd.Description != "" {
            itemText += " " + Description.Render(cmd.Description)
        }

        // Add shortcut aligned right
        if cmd.Shortcut != "" {
            shortcutText := Shortcut.Render(cmd.Shortcut)
            padding := m.width - lipgloss.Width(itemText) - lipgloss.Width(shortcutText) - 4
            if padding > 0 {
                itemText += strings.Repeat(" ", padding) + shortcutText
            }
        }

        // Apply selection style
        if i == m.cursor {
            itemText = SelectedItem.Render(itemText)
        } else {
            itemText = NormalItem.Render(itemText)
        }

        b.WriteString(itemText + "\n")
    }

    // Status bar
    status := fmt.Sprintf("%d/%d commands", len(m.filtered), len(m.commands))
    b.WriteString(StatusBar.Render(status))

    return PaletteStyle.Render(b.String())
}
```

---

## Complete Example: Command Palette

```go
package main

import (
    "fmt"
    "os"
    "strings"

    "github.com/charmbracelet/bubbles/textinput"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
    "github.com/sahilm/fuzzy"
)

// Styles
var (
    paletteStyle = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color("62")).
        Padding(1, 2).
        Width(60)

    promptStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("205")).
        Bold(true)

    normalItemStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("252")).
        PaddingLeft(2)

    selectedItemStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("212")).
        Background(lipgloss.Color("236")).
        Bold(true).
        PaddingLeft(2)

    matchStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("212")).
        Bold(true)

    descStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("240"))

    shortcutStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("241"))

    statusStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("241")).
        MarginTop(1)
)

// Command represents an action in the palette
type Command struct {
    ID          string
    Name        string
    Description string
    Shortcut    string
}

// Model is the command palette model
type Model struct {
    textInput textinput.Model
    commands  []Command
    filtered  []fuzzy.Match
    cursor    int
    selected  *Command
    quitting  bool
}

// New creates a new command palette
func New(commands []Command) Model {
    ti := textinput.New()
    ti.Placeholder = "Type to search commands..."
    ti.Focus()
    ti.CharLimit = 100
    ti.Width = 50

    m := Model{
        textInput: ti,
        commands:  commands,
    }
    m.filterCommands()
    return m
}

func (m *Model) filterCommands() {
    query := m.textInput.Value()

    if query == "" {
        m.filtered = make([]fuzzy.Match, len(m.commands))
        for i, cmd := range m.commands {
            m.filtered[i] = fuzzy.Match{
                Str:   cmd.Name,
                Index: i,
            }
        }
        return
    }

    names := make([]string, len(m.commands))
    for i, cmd := range m.commands {
        names[i] = cmd.Name
    }

    m.filtered = fuzzy.Find(query, names)

    if m.cursor >= len(m.filtered) {
        m.cursor = max(0, len(m.filtered)-1)
    }
}

func (m Model) Init() tea.Cmd {
    return textinput.Blink
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+c", "esc":
            m.quitting = true
            return m, tea.Quit

        case "enter":
            if len(m.filtered) > 0 && m.cursor < len(m.filtered) {
                idx := m.filtered[m.cursor].Index
                m.selected = &m.commands[idx]
            }
            m.quitting = true
            return m, tea.Quit

        case "up", "ctrl+p":
            if m.cursor > 0 {
                m.cursor--
            }
            return m, nil

        case "down", "ctrl+n":
            if m.cursor < len(m.filtered)-1 {
                m.cursor++
            }
            return m, nil

        case "ctrl+u":
            m.textInput.SetValue("")
            m.filterCommands()
            return m, nil
        }
    }

    var cmd tea.Cmd
    m.textInput, cmd = m.textInput.Update(msg)
    m.filterCommands()
    return m, cmd
}

func (m Model) View() string {
    if m.quitting {
        if m.selected != nil {
            return fmt.Sprintf("Selected: %s\n", m.selected.Name)
        }
        return "Cancelled\n"
    }

    var b strings.Builder

    // Search input
    b.WriteString(promptStyle.Render("> "))
    b.WriteString(m.textInput.View())
    b.WriteString("\n\n")

    // Results
    maxVisible := min(10, len(m.filtered))
    for i := 0; i < maxVisible; i++ {
        match := m.filtered[i]
        cmd := m.commands[match.Index]

        // Render with highlights
        itemText := renderMatch(match)

        // Add description
        if cmd.Description != "" {
            itemText += " " + descStyle.Render("- "+cmd.Description)
        }

        // Apply selection style
        if i == m.cursor {
            b.WriteString(selectedItemStyle.Render("  "+itemText))
        } else {
            b.WriteString(normalItemStyle.Render("  " + itemText))
        }

        // Add shortcut on the right
        if cmd.Shortcut != "" {
            b.WriteString("  " + shortcutStyle.Render("["+cmd.Shortcut+"]"))
        }

        b.WriteString("\n")
    }

    if len(m.filtered) == 0 {
        b.WriteString(descStyle.Render("  No matching commands\n"))
    }

    // Status
    status := fmt.Sprintf("%d/%d commands", len(m.filtered), len(m.commands))
    b.WriteString(statusStyle.Render(status))

    return paletteStyle.Render(b.String())
}

func renderMatch(match fuzzy.Match) string {
    matchSet := make(map[int]bool)
    for _, idx := range match.MatchedIndexes {
        matchSet[idx] = true
    }

    var result strings.Builder
    for i, char := range match.Str {
        if matchSet[i] {
            result.WriteString(matchStyle.Render(string(char)))
        } else {
            result.WriteString(string(char))
        }
    }
    return result.String()
}

func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}

func min(a, b int) int {
    if a < b {
        return a
    }
    return b
}

func main() {
    commands := []Command{
        {ID: "open", Name: "Open File", Description: "Open a file in editor", Shortcut: "Cmd+O"},
        {ID: "save", Name: "Save File", Description: "Save current file", Shortcut: "Cmd+S"},
        {ID: "save-as", Name: "Save As", Description: "Save file with new name", Shortcut: "Cmd+Shift+S"},
        {ID: "close", Name: "Close Tab", Description: "Close current tab", Shortcut: "Cmd+W"},
        {ID: "find", Name: "Find", Description: "Search in file", Shortcut: "Cmd+F"},
        {ID: "replace", Name: "Find and Replace", Description: "Search and replace text", Shortcut: "Cmd+H"},
        {ID: "goto", Name: "Go to Line", Description: "Jump to line number", Shortcut: "Cmd+G"},
        {ID: "symbol", Name: "Go to Symbol", Description: "Jump to symbol", Shortcut: "Cmd+Shift+O"},
        {ID: "format", Name: "Format Document", Description: "Auto-format code", Shortcut: "Cmd+Shift+F"},
        {ID: "terminal", Name: "Toggle Terminal", Description: "Show/hide terminal", Shortcut: "Cmd+`"},
        {ID: "sidebar", Name: "Toggle Sidebar", Description: "Show/hide sidebar", Shortcut: "Cmd+B"},
        {ID: "palette", Name: "Command Palette", Description: "Open command palette", Shortcut: "Cmd+Shift+P"},
        {ID: "settings", Name: "Open Settings", Description: "Open preferences", Shortcut: "Cmd+,"},
        {ID: "git-commit", Name: "Git: Commit", Description: "Commit staged changes", Shortcut: ""},
        {ID: "git-push", Name: "Git: Push", Description: "Push to remote", Shortcut: ""},
        {ID: "git-pull", Name: "Git: Pull", Description: "Pull from remote", Shortcut: ""},
    }

    p := tea.NewProgram(New(commands))
    finalModel, err := p.Run()
    if err != nil {
        fmt.Printf("Error: %v\n", err)
        os.Exit(1)
    }

    // Access the selected command
    m := finalModel.(Model)
    if m.selected != nil {
        fmt.Printf("\nExecuting: %s (ID: %s)\n", m.selected.Name, m.selected.ID)
    }
}
```

---

## Integration with tmux Popups

For a global CMD+K experience, use tmux popups:

**~/.tmux.conf:**
```bash
# Bind Alt-k (or remap CMD+K in your terminal emulator)
bind-key -n M-k display-popup -E -w 80% -h 60% "command-palette"
```

**Terminal emulator mapping (Ghostty example):**
```toml
keybind = cmd+k=text:\x1bk  # Sends Alt-k
```

---

## Sources

- [go-fuzzyfinder GitHub](https://github.com/ktr0731/go-fuzzyfinder)
- [sahilm/fuzzy GitHub](https://github.com/sahilm/fuzzy)
- [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles)
- [charmbracelet/lipgloss](https://github.com/charmbracelet/lipgloss)
- [bubbletea-overlay](https://github.com/rmhubbert/bubbletea-overlay)
- [Bubble Tea list package](https://pkg.go.dev/github.com/charmbracelet/bubbles/list)
- [Bubble Tea textinput](https://pkg.go.dev/github.com/charmbracelet/bubbles/textinput)
- [Command Palette UX Patterns](https://medium.com/design-bootcamp/command-palette-ux-patterns-1-d6b6e68f30c1)
- [go-fzf - Bubble Tea based fzf](https://github.com/koki-develop/go-fzf)
