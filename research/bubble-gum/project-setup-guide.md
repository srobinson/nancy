# Bubble Tea Project Setup Guide

A step-by-step guide for bootstrapping a new terminal UI application using Charmbracelet's Bubble Tea framework.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Go Module Initialization](#step-1-go-module-initialization)
3. [Installing Dependencies](#step-2-installing-dependencies)
4. [Project Directory Structure](#step-3-project-directory-structure)
5. [Main.go Boilerplate](#step-4-maingo-boilerplate)
6. [Model/Update/View Architecture](#step-5-modelupdateview-architecture)
7. [Build and Run Commands](#step-6-build-and-run-commands)
8. [Common Gotchas](#common-gotchas-for-new-projects)
9. [Next Steps](#next-steps)

---

## Prerequisites

- Go 1.21 or later installed
- Basic familiarity with Go syntax
- A terminal emulator (iTerm2, Alacritty, Windows Terminal, etc.)

---

## Step 1: Go Module Initialization

Create a new directory for your project and initialize a Go module:

```bash
mkdir my-tui-app
cd my-tui-app
go mod init github.com/yourusername/my-tui-app
```

Replace `github.com/yourusername/my-tui-app` with your actual module path.

---

## Step 2: Installing Dependencies

### Core Dependencies

Install the three essential Charmbracelet libraries:

```bash
# Bubble Tea - The TUI framework (core)
go get github.com/charmbracelet/bubbletea

# Bubbles - Pre-built UI components (spinners, text inputs, lists, etc.)
go get github.com/charmbracelet/bubbles

# Lip Gloss - Styling library for colors, borders, and layouts
go get github.com/charmbracelet/lipgloss
```

### Tidy Dependencies

After adding dependencies, run:

```bash
go mod tidy
```

### Version Note (v2 Beta)

As of late 2025, Bubble Tea v2 is in beta. For production projects, use the stable v1:

```go
import tea "github.com/charmbracelet/bubbletea"
```

For v2 beta (when stable):
```go
import tea "github.com/charmbracelet/bubbletea/v2"
```

---

## Step 3: Project Directory Structure

### Simple Project (Recommended for Starting)

For small projects or learning, keep it flat:

```
my-tui-app/
  go.mod
  go.sum
  main.go
```

### Standard Project Structure

For larger applications, use this structure:

```
my-tui-app/
  cmd/
    my-tui-app/
      main.go           # Entry point - minimal, just starts the app
  internal/
    app/
      app.go            # Main application model and logic
    ui/
      styles.go         # Lipgloss style definitions
      components/       # Custom Bubble Tea components
        header.go
        footer.go
    model/
      state.go          # Application state definitions
  go.mod
  go.sum
  Makefile              # Build commands
  README.md
```

### Key Directory Conventions

| Directory | Purpose |
|-----------|---------|
| `cmd/` | Application entry points. Keep `main.go` minimal. |
| `internal/` | Private code that cannot be imported by external projects. |
| `internal/ui/` | UI components and styles. |
| `internal/app/` | Core application logic. |

**Important**: Avoid over-nesting. Go favors shallow hierarchies (1-2 levels deep).

---

## Step 4: Main.go Boilerplate

Create `main.go` with this minimal boilerplate:

```go
package main

import (
    "fmt"
    "os"

    tea "github.com/charmbracelet/bubbletea"
)

func main() {
    // Create the Bubble Tea program with initial model
    p := tea.NewProgram(initialModel())

    // Run the program
    if _, err := p.Run(); err != nil {
        fmt.Fprintf(os.Stderr, "Error running program: %v\n", err)
        os.Exit(1)
    }
}
```

### Program Options

Common options when creating the program:

```go
p := tea.NewProgram(
    initialModel(),
    tea.WithAltScreen(),        // Use alternate screen buffer (full-screen mode)
    tea.WithMouseCellMotion(),  // Enable mouse support
)
```

---

## Step 5: Model/Update/View Architecture

Bubble Tea uses **The Elm Architecture** (Model-View-Update pattern):

1. **Model** - Holds application state
2. **Init** - Returns initial commands
3. **Update** - Handles messages and updates state
4. **View** - Renders the UI as a string

### Complete Example

```go
package main

import (
    "fmt"
    "os"

    tea "github.com/charmbracelet/bubbletea"
)

// Model holds all application state
type model struct {
    choices  []string         // List items
    cursor   int              // Current cursor position
    selected map[int]struct{} // Selected items (using map as a set)
}

// initialModel returns the starting state
func initialModel() model {
    return model{
        choices:  []string{"Option 1", "Option 2", "Option 3"},
        selected: make(map[int]struct{}),
    }
}

// Init runs any initial commands (return nil if none needed)
func (m model) Init() tea.Cmd {
    return nil
}

// Update handles messages and returns updated model + optional command
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {

    // Handle keyboard input
    case tea.KeyMsg:
        switch msg.String() {

        // Quit
        case "ctrl+c", "q":
            return m, tea.Quit

        // Navigate up
        case "up", "k":
            if m.cursor > 0 {
                m.cursor--
            }

        // Navigate down
        case "down", "j":
            if m.cursor < len(m.choices)-1 {
                m.cursor++
            }

        // Toggle selection
        case "enter", " ":
            if _, ok := m.selected[m.cursor]; ok {
                delete(m.selected, m.cursor)
            } else {
                m.selected[m.cursor] = struct{}{}
            }
        }

    // Handle window resize
    case tea.WindowSizeMsg:
        // Store width/height if needed: m.width = msg.Width
    }

    return m, nil
}

// View renders the UI as a string
func (m model) View() string {
    s := "Select an option:\n\n"

    for i, choice := range m.choices {
        // Cursor indicator
        cursor := " "
        if m.cursor == i {
            cursor = ">"
        }

        // Checkbox indicator
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
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}
```

### Adding Lipgloss Styling

```go
import "github.com/charmbracelet/lipgloss"

// Define styles
var (
    titleStyle = lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("#FAFAFA")).
        Background(lipgloss.Color("#7D56F4")).
        Padding(0, 1)

    selectedStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("205")).
        Bold(true)

    normalStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("252"))
)

// Use in View()
func (m model) View() string {
    s := titleStyle.Render("My TUI App") + "\n\n"
    // ... rest of rendering
    return s
}
```

### Using Bubbles Components

Example with a spinner:

```go
import (
    "github.com/charmbracelet/bubbles/spinner"
    "github.com/charmbracelet/lipgloss"
)

type model struct {
    spinner spinner.Model
    loading bool
}

func initialModel() model {
    s := spinner.New()
    s.Spinner = spinner.Dot
    s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
    return model{spinner: s, loading: true}
}

func (m model) Init() tea.Cmd {
    return m.spinner.Tick  // Start the spinner animation
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case spinner.TickMsg:
        var cmd tea.Cmd
        m.spinner, cmd = m.spinner.Update(msg)
        return m, cmd
    // ... other cases
    }
    return m, nil
}

func (m model) View() string {
    if m.loading {
        return fmt.Sprintf("%s Loading...", m.spinner.View())
    }
    return "Done!"
}
```

---

## Step 6: Build and Run Commands

### Development

```bash
# Run directly
go run .

# Run with specific file
go run main.go
```

### Building

```bash
# Build for current platform
go build -o my-tui-app .

# Build with optimizations
go build -ldflags="-s -w" -o my-tui-app .
```

### Cross-Platform Builds

```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o my-tui-app-linux .

# Windows
GOOS=windows GOARCH=amd64 go build -o my-tui-app.exe .

# macOS (Intel)
GOOS=darwin GOARCH=amd64 go build -o my-tui-app-darwin .

# macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o my-tui-app-darwin-arm64 .
```

### Sample Makefile

```makefile
.PHONY: build run clean

build:
	go build -o bin/my-tui-app .

run:
	go run .

clean:
	rm -rf bin/

lint:
	golangci-lint run

test:
	go test -v ./...
```

---

## Common Gotchas for New Projects

### 1. Cannot Use fmt.Println for Debugging

The TUI occupies stdout, so regular print statements won't work. Use file logging instead:

```go
import "github.com/charmbracelet/bubbletea"

func main() {
    // Log to a file for debugging
    f, _ := tea.LogToFile("debug.log", "debug")
    defer f.Close()

    // Now you can use log.Print() and it goes to the file
    log.Print("Starting application...")

    p := tea.NewProgram(initialModel())
    p.Run()
}
```

### 2. State Mutations Don't Trigger Re-renders

Always return the updated model from `Update()`. Direct mutations without returning won't cause a re-render:

```go
// WRONG - won't re-render
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.cursor++  // Mutation without proper return
    return m, nil  // This works, but be careful with pointers
}

// CORRECT - always return updated model
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.cursor++
    return m, nil  // Return the modified model
}
```

### 3. Manual Signal Handling Required

Bubble Tea catches all keystrokes, including `Ctrl+C`. You must handle quit signals yourself:

```go
case tea.KeyMsg:
    switch msg.String() {
    case "ctrl+c", "q", "esc":
        return m, tea.Quit
    }
```

### 4. Windows Resize Limitations

Windows does not support `SIGWINCH`, so resize events may not work as expected. Test on your target platforms.

### 5. Batching Commands is Verbose

When returning multiple commands, use `tea.Batch()`:

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd

    // Update spinner
    var cmd tea.Cmd
    m.spinner, cmd = m.spinner.Update(msg)
    cmds = append(cmds, cmd)

    // Add another command
    cmds = append(cmds, someOtherCommand())

    return m, tea.Batch(cmds...)
}
```

### 6. Subcomponent Init Must Be Called

When using Bubbles components, call their `Init()` in your model's `Init()`:

```go
func (m model) Init() tea.Cmd {
    return tea.Batch(
        m.spinner.Tick,      // Spinner needs tick to animate
        textinput.Blink,     // Text input needs blink for cursor
    )
}
```

### 7. Model Must Satisfy tea.Model Interface

Ensure your model implements all required methods:

```go
// Required interface
type Model interface {
    Init() Cmd
    Update(Msg) (Model, Cmd)
    View() string
}
```

### 8. Avoid Large View() Computations

`View()` is called frequently. Keep it fast and avoid expensive operations:

```go
// WRONG - computing in View()
func (m model) View() string {
    result := expensiveCalculation()  // Bad!
    return result
}

// CORRECT - compute in Update(), render in View()
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.cachedResult = expensiveCalculation()
    return m, nil
}

func (m model) View() string {
    return m.cachedResult  // Just render cached value
}
```

---

## Next Steps

### Learn More

- [Official Bubble Tea Tutorial](https://github.com/charmbracelet/bubbletea/tree/main/tutorials)
- [Bubble Tea Examples](https://github.com/charmbracelet/bubbletea/tree/main/examples)
- [Bubbles Components](https://github.com/charmbracelet/bubbles)
- [Lip Gloss Styling](https://github.com/charmbracelet/lipgloss)

### Available Bubbles Components

| Component | Purpose |
|-----------|---------|
| `spinner` | Loading indicators |
| `textinput` | Single-line text input |
| `textarea` | Multi-line text input |
| `list` | Scrollable list with filtering |
| `table` | Data tables |
| `viewport` | Scrollable content area |
| `progress` | Progress bars |
| `paginator` | Pagination controls |
| `help` | Keybinding help display |
| `filepicker` | File selection |

### Ecosystem Libraries

- **Harmonica** - Spring animation library
- **Glamour** - Markdown rendering
- **BubbleZone** - Mouse event tracking

---

## Quick Start Template

For a production-ready starting point, use the official template:

```bash
# Clone the template
git clone https://github.com/charmbracelet/bubbletea-app-template my-app
cd my-app

# Update module name
go mod edit -module github.com/yourusername/my-app

# Install dependencies
go mod tidy

# Run
go run .
```

This template includes:
- CI/CD workflows for GitHub Actions
- GoReleaser configuration
- golangci-lint setup
- Sample application with spinner

---

## Sources

- [Bubble Tea GitHub Repository](https://github.com/charmbracelet/bubbletea)
- [Bubble Tea Basics Tutorial](https://github.com/charmbracelet/bubbletea/blob/main/tutorials/basics/README.md)
- [Bubbles Components](https://github.com/charmbracelet/bubbles)
- [Lip Gloss Styling](https://github.com/charmbracelet/lipgloss)
- [Bubble Tea App Template](https://github.com/charmbracelet/bubbletea-app-template)
- [Go Project Layout Standards](https://github.com/golang-standards/project-layout)
- [Interactive CLIs with Bubbletea - Inngest Blog](https://www.inngest.com/blog/interactive-clis-with-bubbletea)
- [Bubble Tea v2 Package Docs](https://pkg.go.dev/github.com/charmbracelet/bubbletea/v2)
