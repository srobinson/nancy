# Charm Ecosystem Reference Guide

A comprehensive guide to the Charm ecosystem for building terminal user interfaces (TUIs) in Go.

---

## Table of Contents

1. [Ecosystem Overview](#ecosystem-overview)
2. [Core Framework: Bubble Tea](#core-framework-bubble-tea)
3. [Styling: Lip Gloss](#styling-lip-gloss)
4. [Components: Bubbles](#components-bubbles)
5. [Forms & Prompts: Huh](#forms--prompts-huh)
6. [Animations: Harmonica](#animations-harmonica)
7. [Markdown Rendering: Glamour](#markdown-rendering-glamour)
8. [Logging: Log](#logging-log)
9. [Shell Scripting: Gum](#shell-scripting-gum)
10. [SSH Applications: Wish](#ssh-applications-wish)
11. [Git Server: Soft Serve](#git-server-soft-serve)
12. [Terminal Recording: VHS](#terminal-recording-vhs)
13. [Third-Party Libraries](#third-party-libraries)
14. [Library Relationships](#library-relationships)

---

## Ecosystem Overview

The Charm ecosystem is a collection of Go libraries for building beautiful, functional terminal applications. At its core is Bubble Tea, a framework based on The Elm Architecture that provides a functional, declarative approach to TUI development.

**Key Statistics:**
- Bubble Tea is imported by 9,310+ packages
- Over 10,000 applications built with Bubble Tea
- Active community with libraries covering styling, components, forms, animations, and more

**Core Philosophy:**
- Functional design paradigms from The Elm Architecture
- Model-View-Update (MVU) pattern for state management
- Composable components that work together seamlessly
- Beautiful, accessible terminal interfaces

---

## Core Framework: Bubble Tea

**Package:** `github.com/charmbracelet/bubbletea`

Bubble Tea is the foundation of the Charm TUI ecosystem. It provides a functional framework for building terminal applications using the Model-View-Update architecture.

### Architecture

Every Bubble Tea program consists of:

1. **Model** - Describes the application state
2. **Init()** - Returns an initial command to run
3. **Update()** - Handles incoming events and updates the model
4. **View()** - Renders the UI based on the model data

### Basic Example

```go
package main

import (
    "fmt"
    "os"
    tea "github.com/charmbracelet/bubbletea"
)

type model struct {
    count int
}

func (m model) Init() tea.Cmd {
    return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "q", "ctrl+c":
            return m, tea.Quit
        case "up":
            m.count++
        case "down":
            m.count--
        }
    }
    return m, nil
}

func (m model) View() string {
    return fmt.Sprintf("Count: %d\n\nPress up/down to change, q to quit.", m.count)
}

func main() {
    p := tea.NewProgram(model{})
    if _, err := p.Run(); err != nil {
        fmt.Printf("Error: %v\n", err)
        os.Exit(1)
    }
}
```

### Key Features

- **Framerate-based renderer** - Efficient rendering with configurable frame rates
- **Mouse support** - Handle mouse clicks, scrolls, and motion
- **Focus reporting** - Know when your terminal gains/loses focus
- **Bracketed paste** - Properly handle pasted text
- **Alternate screen buffer** - Full-window applications
- **Inline mode** - Embed TUIs within existing terminal output

### Commands (tea.Cmd)

Commands are functions that perform I/O and return messages:

```go
func checkServer() tea.Msg {
    res, err := http.Get("https://example.com")
    if err != nil {
        return errMsg{err}
    }
    return statusMsg(res.StatusCode)
}

// In Init() or Update():
return m, checkServer
```

### Program Options

```go
p := tea.NewProgram(model{},
    tea.WithAltScreen(),        // Full-window mode
    tea.WithMouseCellMotion(),  // Mouse support
    tea.WithoutCatchPanics(),   // Debug mode
)
```

---

## Styling: Lip Gloss

**Package:** `github.com/charmbracelet/lipgloss`

Lip Gloss is a declarative styling library for terminal applications - think CSS for the command line.

### Basic Styling

```go
import "github.com/charmbracelet/lipgloss"

style := lipgloss.NewStyle().
    Bold(true).
    Foreground(lipgloss.Color("#FAFAFA")).
    Background(lipgloss.Color("#7D56F4")).
    PaddingTop(2).
    PaddingLeft(4).
    Width(22)

output := style.Render("Hello, World!")
```

### Colors

```go
// ANSI colors (0-15)
lipgloss.Color("5")

// ANSI 256 colors
lipgloss.Color("86")

// Hex colors
lipgloss.Color("#FF6347")

// Adaptive colors (light/dark mode)
lipgloss.AdaptiveColor{Light: "236", Dark: "248"}
```

### Text Formatting

```go
style := lipgloss.NewStyle().
    Bold(true).
    Italic(true).
    Underline(true).
    Strikethrough(true).
    Blink(true).
    Faint(true)
```

### Layout

```go
// Padding and margins
style := lipgloss.NewStyle().
    Padding(1, 2).           // vertical, horizontal
    Margin(2, 4, 3, 1)       // top, right, bottom, left

// Alignment
style := lipgloss.NewStyle().
    Width(40).
    Align(lipgloss.Center)   // Left, Center, Right
```

### Borders

```go
style := lipgloss.NewStyle().
    BorderStyle(lipgloss.RoundedBorder()).
    BorderForeground(lipgloss.Color("228")).
    BorderTop(true).
    BorderLeft(true).
    Padding(1, 2)

// Available border styles:
// NormalBorder(), RoundedBorder(), BlockBorder(),
// ThickBorder(), DoubleBorder(), HiddenBorder(), ASCIIBorder()
```

### Joining Elements

```go
// Horizontal join
lipgloss.JoinHorizontal(lipgloss.Top, left, right)

// Vertical join
lipgloss.JoinVertical(lipgloss.Left, top, bottom)
```

---

## Components: Bubbles

**Package:** `github.com/charmbracelet/bubbles`

Bubbles is the official component library for Bubble Tea, providing ready-to-use UI elements.

### Available Components

| Component | Description |
|-----------|-------------|
| `spinner` | Animated loading indicators |
| `textinput` | Single-line text input |
| `textarea` | Multi-line text input |
| `table` | Scrollable data tables |
| `list` | Filterable, paginated lists |
| `progress` | Progress bars |
| `paginator` | Page navigation |
| `viewport` | Scrollable content areas |
| `filepicker` | File system navigation |
| `timer` | Countdown timer |
| `stopwatch` | Count-up timer |
| `help` | Keybinding help views |
| `key` | Keybinding management |
| `cursor` | Text cursor management |

### Spinner Example

```go
import (
    "github.com/charmbracelet/bubbles/spinner"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

type model struct {
    spinner spinner.Model
}

func initialModel() model {
    s := spinner.New()
    s.Spinner = spinner.Dot  // Dot, Line, MiniDot, Jump, Pulse, etc.
    s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
    return model{spinner: s}
}

func (m model) Init() tea.Cmd {
    return m.spinner.Tick
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case spinner.TickMsg:
        var cmd tea.Cmd
        m.spinner, cmd = m.spinner.Update(msg)
        return m, cmd
    }
    return m, nil
}

func (m model) View() string {
    return m.spinner.View() + " Loading..."
}
```

### Text Input Example

```go
import "github.com/charmbracelet/bubbles/textinput"

ti := textinput.New()
ti.Placeholder = "Enter your name"
ti.Focus()
ti.CharLimit = 50
ti.Width = 30
```

### Table Example

```go
import "github.com/charmbracelet/bubbles/table"

columns := []table.Column{
    {Title: "ID", Width: 10},
    {Title: "Name", Width: 20},
    {Title: "Email", Width: 30},
}

rows := []table.Row{
    {"1", "Alice", "alice@example.com"},
    {"2", "Bob", "bob@example.com"},
}

t := table.New(
    table.WithColumns(columns),
    table.WithRows(rows),
    table.WithFocused(true),
    table.WithHeight(7),
)
```

### List Example

```go
import "github.com/charmbracelet/bubbles/list"

type item struct {
    title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

items := []list.Item{
    item{title: "Go", desc: "A compiled language"},
    item{title: "Python", desc: "An interpreted language"},
}

l := list.New(items, list.NewDefaultDelegate(), 0, 0)
l.Title = "Languages"
l.SetFilteringEnabled(true)
```

---

## Forms & Prompts: Huh

**Package:** `github.com/charmbracelet/huh`

Huh is a library for building interactive forms and prompts with first-class accessibility support.

### Field Types

- **Input** - Single-line text input
- **Text** - Multi-line text input
- **Select** - Single option selection
- **MultiSelect** - Multiple option selection
- **Confirm** - Yes/No confirmation

### Basic Form Example

```go
import "github.com/charmbracelet/huh"

var name string
var age int
var confirmed bool

form := huh.NewForm(
    huh.NewGroup(
        huh.NewInput().
            Title("What's your name?").
            Value(&name),

        huh.NewSelect[int]().
            Title("How old are you?").
            Options(
                huh.NewOption("Under 18", 17),
                huh.NewOption("18-30", 25),
                huh.NewOption("Over 30", 40),
            ).
            Value(&age),

        huh.NewConfirm().
            Title("Is this correct?").
            Value(&confirmed),
    ),
)

err := form.Run()
```

### Validation

```go
huh.NewInput().
    Title("Email").
    Validate(func(s string) error {
        if !strings.Contains(s, "@") {
            return errors.New("invalid email")
        }
        return nil
    }).
    Value(&email)
```

### Bubble Tea Integration

Huh forms are tea.Model implementations and can be embedded in Bubble Tea applications:

```go
type Model struct {
    form *huh.Form
}

func (m Model) Init() tea.Cmd {
    return m.form.Init()
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    form, cmd := m.form.Update(msg)
    if f, ok := form.(*huh.Form); ok {
        m.form = f
    }
    return m, cmd
}

func (m Model) View() string {
    if m.form.State == huh.StateCompleted {
        return "Form completed!"
    }
    return m.form.View()
}
```

### Theming

```go
form := huh.NewForm(/*...*/).
    WithTheme(huh.ThemeDracula())

// Available themes: ThemeBase(), ThemeCharm(), ThemeDracula(),
// ThemeCatppuccin(), ThemeBase16()
```

### Accessibility

```go
form := huh.NewForm(/*...*/).
    WithAccessible(true)  // Screen reader friendly mode
```

---

## Animations: Harmonica

**Package:** `github.com/charmbracelet/harmonica`

Harmonica is a physics-based animation library for smooth, natural motion.

### Spring Animation

```go
import "github.com/charmbracelet/harmonica"

// Create a spring with:
// - frequency: oscillations per second
// - damping: 0-1 (lower = springier)
spring := harmonica.NewSpring(harmonica.FPS(60), 6.0, 0.5)

// Update each frame
newPos, newVel := spring.Update(currentPos, currentVel, targetPos)
```

### Damping Ratios

- **Under-damped (< 1)** - Oscillates before settling, springy feel
- **Critically-damped (= 1)** - Fastest to settle without oscillation
- **Over-damped (> 1)** - Slow settling, no oscillation

### Use Cases

- Smooth scrolling
- Menu transitions
- Progress bar animations
- Interactive element responses

---

## Markdown Rendering: Glamour

**Package:** `github.com/charmbracelet/glamour`

Glamour renders styled markdown in the terminal.

### Basic Usage

```go
import "github.com/charmbracelet/glamour"

markdown := `# Hello World

This is **bold** and *italic* text.

- List item 1
- List item 2
`

out, err := glamour.Render(markdown, "dark")
fmt.Print(out)
```

### Available Styles

- `dark` - Dark terminal theme
- `light` - Light terminal theme
- `pink` - Pink accent theme
- `dracula` - Dracula color scheme
- `tokyo-night` - Tokyo Night theme
- `ascii` - ASCII-only output
- `notty` - No styling (for non-TTY output)
- `auto` - Auto-detect based on terminal

### Custom Renderer

```go
import (
    "github.com/charmbracelet/glamour"
    "github.com/charmbracelet/glamour/styles"
    "github.com/muesli/termenv"
)

renderer, err := glamour.NewTermRenderer(
    glamour.WithStandardStyle(styles.DarkStyle),
    glamour.WithWordWrap(120),
    glamour.WithColorProfile(termenv.TrueColor),
)

out, err := renderer.Render(markdown)
```

---

## Logging: Log

**Package:** `github.com/charmbracelet/log`

A minimal, colorful logging library with Lip Gloss styling.

### Basic Usage

```go
import "github.com/charmbracelet/log"

log.Debug("Debug message")
log.Info("Info message")
log.Warn("Warning message")
log.Error("Error message")
log.Fatal("Fatal message")  // Exits the program
```

### Structured Logging

```go
log.Info("User logged in", "user", "alice", "ip", "192.168.1.1")
```

### Output Formats

- **TextFormatter** (default) - Colorful human-readable output
- **JSONFormatter** - JSON structured output
- **LogfmtFormatter** - Logfmt structured output

```go
logger := log.New(os.Stderr)
logger.SetFormatter(log.JSONFormatter)
```

### Log Levels

```go
logger.SetLevel(log.DebugLevel)
// Available: DebugLevel, InfoLevel, WarnLevel, ErrorLevel, FatalLevel
```

---

## Shell Scripting: Gum

**Package:** `github.com/charmbracelet/gum` (CLI tool)

Gum brings Bubble Tea and Lip Gloss power to shell scripts without writing Go code.

### Input Commands

```bash
# Single line input
NAME=$(gum input --placeholder "Enter your name")

# Password input
PASSWORD=$(gum input --password)

# Multi-line text
NOTES=$(gum write --placeholder "Enter notes...")
```

### Selection Commands

```bash
# Single selection
TYPE=$(gum choose "feat" "fix" "docs" "style" "refactor")

# Multiple selection
TOPPINGS=$(gum choose --no-limit "lettuce" "tomato" "cheese" "onion")

# Fuzzy filter
FILE=$(gum filter < files.txt)
```

### Confirmation

```bash
gum confirm "Proceed with installation?" && ./install.sh
```

### Spinners

```bash
gum spin --spinner dot --title "Installing..." -- npm install
```

### Styled Output

```bash
gum style --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "Hello, World!"
```

---

## SSH Applications: Wish

**Package:** `github.com/charmbracelet/wish`

Wish is an SSH server library for building SSH-accessible applications.

### Basic SSH Server

```go
import (
    "github.com/charmbracelet/wish"
    "github.com/charmbracelet/wish/logging"
    "github.com/charmbracelet/wish/bubbletea"
)

s, err := wish.NewServer(
    wish.WithAddress(":23234"),
    wish.WithHostKeyPath(".ssh/term_info_ed25519"),
    wish.WithMiddleware(
        bubbletea.Middleware(teaHandler),
        logging.Middleware(),
    ),
)

log.Fatal(s.ListenAndServe())
```

### Key Features

- Serve TUIs over SSH
- Built-in middleware (logging, access control, git)
- Easy integration with Bubble Tea
- No openssh-server required

### Middlewares

- **logging** - Connection logging
- **bubbletea** - Serve Bubble Tea apps over SSH
- **git** - Git server functionality
- **activeterm** - Require active terminal
- **accesscontrol** - Command restrictions

---

## Git Server: Soft Serve

**Package:** `github.com/charmbracelet/soft-serve`

A self-hostable Git server with a beautiful TUI.

### Features

- Git over SSH, HTTP(s), and Git protocol
- Git LFS support
- Server-side hooks
- User authentication and authorization
- Beautiful TUI for repository browsing

### Installation

```bash
go install github.com/charmbracelet/soft-serve/cmd/soft@latest
soft serve
```

---

## Terminal Recording: VHS

**Package:** `github.com/charmbracelet/vhs` (CLI tool)

VHS records terminal sessions as GIFs, MP4s, or WebM files.

### Tape File Example

```
# demo.tape
Output demo.gif
Set FontSize 14
Set Width 1200
Set Height 600

Type "echo 'Hello, World!'"
Enter
Sleep 2s
```

### Run Recording

```bash
vhs demo.tape
```

### Output Formats

- GIF
- MP4
- WebM
- PNG sequence

---

## Third-Party Libraries

### BubbleZone

**Package:** `github.com/lrstanley/bubblezone`

Easy mouse event tracking for Bubble Tea components.

```go
import zone "github.com/lrstanley/bubblezone"

// Initialize
zone.NewGlobal()

// Mark clickable areas
zone.Mark("button", buttonView)

// In View(), wrap output
return zone.Scan(fullView)

// In Update(), check clicks
if zone.Get("button").InBounds(msg) {
    // Handle click
}
```

### BubbleTint

**Package:** `github.com/lrstanley/bubbletint`

Color tint collections for terminal applications.

### Bubbletea Overlay

**Package:** `github.com/rmhubbert/bubbletea-overlay`

Modal windows and overlays for Bubble Tea.

### Additional Bubbles (Community)

**Repository:** `github.com/charm-and-friends/additional-bubbles`

Community-maintained components including:
- `bubbleboxer` - Layout multiple bubbles in a tree
- `bubblelister` - Scrollable list without pagination
- Various other community contributions

### ntcharts

Terminal charting library built for Bubble Tea and Lip Gloss.

---

## Library Relationships

```
                          ┌─────────────────┐
                          │   Bubble Tea    │
                          │ (Core Framework)│
                          └────────┬────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
           ▼                       ▼                       ▼
    ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
    │   Bubbles   │        │  Lip Gloss  │        │  Harmonica  │
    │ (Components)│        │  (Styling)  │        │ (Animations)│
    └──────┬──────┘        └──────┬──────┘        └─────────────┘
           │                      │
           │                      ├───────────────┐
           ▼                      ▼               ▼
    ┌─────────────┐        ┌─────────────┐ ┌─────────────┐
    │     Huh     │        │   Glamour   │ │     Log     │
    │   (Forms)   │        │ (Markdown)  │ │  (Logging)  │
    └─────────────┘        └─────────────┘ └─────────────┘

    ┌─────────────┐        ┌─────────────┐ ┌─────────────┐
    │     Gum     │        │    Wish     │ │ Soft Serve  │
    │   (Shell)   │        │    (SSH)    │ │    (Git)    │
    └─────────────┘        └─────────────┘ └─────────────┘
```

### Dependency Summary

| Library | Depends On |
|---------|------------|
| Bubble Tea | (standalone) |
| Lip Gloss | (standalone) |
| Bubbles | Bubble Tea, Lip Gloss |
| Huh | Bubble Tea, Bubbles, Lip Gloss |
| Harmonica | (standalone) |
| Glamour | Lip Gloss |
| Log | Lip Gloss |
| Gum | Bubbles, Lip Gloss |
| Wish | Bubble Tea |
| Soft Serve | Bubble Tea, Lip Gloss, Wish |
| VHS | (standalone CLI) |

### When to Use What

| Use Case | Libraries |
|----------|-----------|
| Full TUI application | Bubble Tea + Bubbles + Lip Gloss |
| Quick form/prompt | Huh |
| Shell script interactivity | Gum |
| Styled CLI output | Lip Gloss |
| Markdown in terminal | Glamour |
| Smooth animations | Harmonica |
| SSH-accessible TUI | Wish + Bubble Tea |
| Beautiful logging | Log |
| Self-hosted Git | Soft Serve |
| Demo recordings | VHS |

---

## Version Information

As of January 2025:
- Bubble Tea v2.0.0-beta.4 (v2 in beta)
- Lip Gloss v2.0.0-beta.2 (v2 in beta)
- Huh v2 available
- Requires Go 1.24.0+

---

## Resources

### Official

- [Charm Homepage](https://charm.sh/)
- [Charm Blog](https://charm.sh/blog/)
- [GitHub Organization](https://github.com/charmbracelet)

### Documentation

- [Bubble Tea README](https://github.com/charmbracelet/bubbletea)
- [Bubbles README](https://github.com/charmbracelet/bubbles)
- [Lip Gloss README](https://github.com/charmbracelet/lipgloss)
- [Huh README](https://github.com/charmbracelet/huh)

### Community

- [Charm & Friends](https://github.com/charm-and-friends) - Community projects
- [Awesome TUIs](https://github.com/rothgar/awesome-tuis) - TUI project list
