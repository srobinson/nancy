# Bubble Tea + tmux Integration Patterns

This document covers integration patterns for running Bubble Tea (and Gum) applications within tmux, particularly in popup windows.

## Table of Contents

1. [Running Bubble Tea Apps in tmux Popups](#running-bubble-tea-apps-in-tmux-popups)
2. [Terminal Resize Events in tmux](#terminal-resize-events-in-tmux)
3. [Executing tmux Commands from Bubble Tea](#executing-tmux-commands-from-bubble-tea)
4. [Best Practices for Popup-Style TUIs](#best-practices-for-popup-style-tuis)
5. [Terminal Emulator Hotkey Flow](#terminal-emulator-hotkey-flow)
6. [Known Issues and Workarounds](#known-issues-and-workarounds)
7. [Complete Examples](#complete-examples)

---

## Running Bubble Tea Apps in tmux Popups

### Basic Usage

tmux popups (introduced in v3.2) provide floating windows perfect for TUI applications:

```bash
# Basic popup running a Bubble Tea app
tmux display-popup -E "my-bubbletea-app"

# With size and position
tmux display-popup -w 80% -h 75% -E "my-bubbletea-app"

# Centered popup with custom dimensions
tmux display-popup -xC -yC -w 60% -h 50% -E "my-bubbletea-app"

# Popup inheriting current pane's working directory
tmux display-popup -d "#{pane_current_path}" -E "my-bubbletea-app"
```

### Key Flags

| Flag | Description |
|------|-------------|
| `-E` | Close popup when command exits (essential for TUIs) |
| `-EE` | Close popup only on successful exit (exit code 0) |
| `-w` | Width (percentage or columns) |
| `-h` | Height (percentage or rows) |
| `-x` | X position (`C` for center, `P` for pane, `M` for mouse) |
| `-y` | Y position |
| `-d` | Working directory |
| `-B` | No border |

### tmux.conf Keybindings

```bash
# Simple popup launcher
bind-key p display-popup -E "my-app"

# Popup with sizing
bind-key P display-popup -w 80% -h 80% -E "my-app"

# Popup at current directory
bind-key o display-popup -d "#{pane_current_path}" -w 80% -h 75% -E "my-app"
```

---

## Terminal Resize Events in tmux

### How Bubble Tea Handles Resize

Bubble Tea automatically handles terminal resize via `SIGWINCH` signals, delivering `tea.WindowSizeMsg` to your `Update` function:

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
        // Update any components that need size info
        m.list.SetSize(msg.Width, msg.Height-4)
        return m, nil
    }
    return m, nil
}
```

### Important Considerations

1. **Initial Size Query is Async**: The first `View()` may be called before `WindowSizeMsg` arrives. Handle this gracefully:

```go
func (m model) View() string {
    if m.width == 0 {
        return "Loading..."
    }
    // Normal rendering
}
```

2. **Windows Limitation**: Windows does not support `SIGWINCH`. Polling workaround:

```go
// Windows polling workaround
func pollWindowSize() tea.Cmd {
    return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
        w, h, _ := term.GetSize(int(os.Stdout.Fd()))
        return tea.WindowSizeMsg{Width: w, Height: h}
    })
}
```

3. **tmux Popup Resize**: When a tmux popup is resized (by dragging corners or using Meta key), `WindowSizeMsg` is sent automatically.

### Required tmux Configuration

```bash
# ~/.tmux.conf - Essential for proper resize and focus handling
set -g focus-events on
set -sg escape-time 0
set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-256color:RGB"
```

---

## Executing tmux Commands from Bubble Tea

### Using Go's exec.Command

For simple tmux commands after quitting the TUI:

```go
package main

import (
    "os"
    "os/exec"

    tea "github.com/charmbracelet/bubbletea"
)

type model struct {
    selectedSession string
    shouldSwitch    bool
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "enter":
            m.shouldSwitch = true
            m.selectedSession = "target-session"
            return m, tea.Quit
        }
    }
    return m, nil
}

func main() {
    p := tea.NewProgram(initialModel())
    finalModel, err := p.Run()
    if err != nil {
        os.Exit(1)
    }

    m := finalModel.(model)
    if m.shouldSwitch && m.selectedSession != "" {
        // Execute tmux command after TUI exits
        exec.Command("tmux", "switch-client", "-t", m.selectedSession).Run()
    }
}
```

### Using tea.Exec for Interactive Commands

For spawning interactive processes (like editors):

```go
type editorFinishedMsg struct{ err error }

func openEditor(filename string) tea.Cmd {
    editor := os.Getenv("EDITOR")
    if editor == "" {
        editor = "vim"
    }
    c := exec.Command(editor, filename)
    return tea.ExecProcess(c, func(err error) tea.Msg {
        return editorFinishedMsg{err}
    })
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "e" {
            return m, openEditor("file.txt")
        }
    case editorFinishedMsg:
        if msg.err != nil {
            m.err = msg.err
        }
        return m, nil
    }
    return m, nil
}
```

### Go tmux Libraries

Several libraries provide programmatic tmux control:

```go
// Using github.com/jubnzv/go-tmux
import "github.com/jubnzv/go-tmux"

// Switch client
tmux.SwitchClient("target-session")

// Select window
tmux.SelectWindow(tmux.Target{Session: "sess", Window: "win"})

// Run arbitrary command
stdout, stderr := tmux.RunCmd([]string{"list-sessions", "-F", "#S"})
```

---

## Best Practices for Popup-Style TUIs

### 1. Output to stderr for Pipe Compatibility

Like `fzf`, render to stderr so stdout can be used for output:

```go
func main() {
    // Render TUI to stderr, keep stdout for output
    p := tea.NewProgram(
        initialModel(),
        tea.WithOutput(os.Stderr),
    )

    finalModel, _ := p.Run()
    m := finalModel.(model)

    // Output selection to stdout (can be piped)
    if m.selected != "" {
        fmt.Println(m.selected)
    }
}
```

Or use `/dev/tty` directly (Unix):

```go
func main() {
    tty, err := os.OpenFile("/dev/tty", os.O_WRONLY, 0)
    if err != nil {
        panic(err)
    }
    defer tty.Close()

    p := tea.NewProgram(initialModel(), tea.WithOutput(tty))
    // ...
}
```

### 2. Use Alt Screen for Full-Window Popups

```go
p := tea.NewProgram(
    initialModel(),
    tea.WithAltScreen(),  // Full-window mode
    tea.WithMouseCellMotion(),  // Mouse support
)
```

### 3. Quick Exit on Selection

For popup selectors, exit immediately on selection:

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "enter":
            m.selected = m.items[m.cursor]
            return m, tea.Quit
        case "esc", "q", "ctrl+c":
            return m, tea.Quit
        }
    }
    return m, nil
}
```

### 4. Handle Window Title Cleanup

Window titles persist after exit (known issue):

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "q" {
            // Reset window title before quitting
            return m, tea.Sequence(
                tea.SetWindowTitle(""),
                tea.Quit,
            )
        }
    }
    return m, nil
}
```

### 5. Graceful Sizing

Account for popup borders and padding:

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        // Account for borders (2 chars each side typically)
        m.width = msg.Width - 4
        m.height = msg.Height - 4

        // Use lipgloss GetFrameSize for styled components
        h, v := m.style.GetFrameSize()
        m.list.SetSize(msg.Width-h, msg.Height-v)
    }
    return m, nil
}
```

---

## Terminal Emulator Hotkey Flow

### Architecture: Emulator -> tmux -> Bubble Tea

```
[Terminal Emulator (Kitty/Alacritty/iTerm)]
    |
    | (Hotkey captured by emulator, sent as escape sequence)
    v
[tmux]
    |
    | (Keybinding triggers display-popup)
    v
[Bubble Tea App in Popup]
    |
    | (User makes selection, app exits)
    v
[tmux executes resulting command]
```

### Alacritty Configuration

```toml
# ~/.config/alacritty/alacritty.toml
[[keyboard.bindings]]
# Send escape sequence for Ctrl+Space to tmux
key = "Space"
mods = "Control"
chars = "\u0000"  # Ctrl+Space

[[keyboard.bindings]]
# Custom sequence for tmux popup trigger
key = "P"
mods = "Command"
chars = "\x1b[80;5u"  # Custom escape sequence
```

### Kitty Configuration

```conf
# ~/.config/kitty/kitty.conf
map cmd+p send_text all \x1bp
map ctrl+space send_text all \x00
```

### tmux Keybindings

```bash
# ~/.tmux.conf

# Ctrl+Space for popup session switcher
bind-key -n C-Space display-popup -E "my-session-picker"

# Prefix + p for project picker
bind-key p display-popup -w 60% -h 60% -E "my-project-picker"

# Alt+g for git popup
bind-key -n M-g display-popup -d "#{pane_current_path}" -w 80% -h 80% -E "lazygit"
```

### Toggle Popup Pattern

Create a persistent popup that can be toggled:

```bash
# Toggle popup - creates/attaches to a popup session
bind-key -n M-3 if-shell -F '#{==:#{session_name},popup}' \
    { detach-client } \
    { display-popup -d "#{pane_current_path}" -xC -yC -w 80% -h 75% -E \
        'tmux attach-session -t popup || tmux new-session -s popup' }

# Hide popup sessions from session list
bind-key s choose-tree -Zs -f '#{?#{m:_popup_*,#{session_name}},0,1}'
```

---

## Known Issues and Workarounds

### 1. Colors Not Rendering in tmux

**Problem**: Colors don't display correctly in tmux, especially over SSH.

**Solution**:
```bash
# ~/.tmux.conf
set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-256color:RGB"
# Or for older tmux:
set -ga terminal-overrides ",xterm-256color:Tc"
```

### 2. Focus Events Not Working

**Problem**: `tea.FocusMsg` and `tea.BlurMsg` not received in tmux.

**Solution**:
```bash
# ~/.tmux.conf
set -g focus-events on
```

### 3. Key Release Messages Not Working (v2)

**Problem**: `tea.KeyReleaseMsgs` not working in tmux on macOS.

**Status**: Known issue in Bubble Tea v2. Works in some terminals without tmux.

### 4. Foreground/Background Color Queries (v2)

**Problem**: Color queries fail in tmux.

**Solution**: Upgrade to tmux 3.4+ (works in 3.4, fails in 3.3a).

### 5. Alt Screen Delay on Startup

**Problem**: Screen jumps around on startup in tmux.

**Status**: Known issue in Bubble Tea v2 with tmux.

### 6. Mouse Support Lost After Popup Close

**Problem**: Mouse support breaks if popup is terminated with Ctrl+C while running fzf or similar.

**Workarounds**:
- Use `--no-mouse` flag for fzf
- Detach and reattach tmux session
- Add mouse mode reset to your status line refresh

### 7. Cursor Flickering in Popups

**Problem**: Cursor briefly flickers at top-left before TUI renders.

**Status**: Known tmux issue. Cosmetic only.

### 8. Resize Artifacts with Lipgloss

**Problem**: Background colors cause word-wrap artifacts on resize.

**Solution**: Use `tea.ClearScreen` command when significant resize occurs:

```go
case tea.WindowSizeMsg:
    if m.width != 0 && (msg.Width != m.width || msg.Height != m.height) {
        m.width = msg.Width
        m.height = msg.Height
        return m, tea.ClearScreen
    }
```

### 9. Window Title Persists After Exit

**Problem**: Window title set by Bubble Tea remains after program exits.

**Workaround**: Set empty title before quitting:
```go
return m, tea.Sequence(tea.SetWindowTitle(""), tea.Quit)
```

---

## Complete Examples

### Session Switcher Popup

```go
// cmd/session-picker/main.go
package main

import (
    "fmt"
    "os"
    "os/exec"
    "strings"

    "github.com/charmbracelet/bubbles/list"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

var docStyle = lipgloss.NewStyle().Margin(1, 2)

type item struct {
    name string
}

func (i item) Title() string       { return i.name }
func (i item) Description() string { return "" }
func (i item) FilterValue() string { return i.name }

type model struct {
    list     list.Model
    selected string
    quitting bool
}

func initialModel() model {
    // Get tmux sessions
    out, _ := exec.Command("tmux", "list-sessions", "-F", "#S").Output()
    sessions := strings.Split(strings.TrimSpace(string(out)), "\n")

    items := make([]list.Item, len(sessions))
    for i, s := range sessions {
        items[i] = item{name: s}
    }

    l := list.New(items, list.NewDefaultDelegate(), 0, 0)
    l.Title = "Switch Session"
    l.SetShowStatusBar(false)
    l.SetFilteringEnabled(true)

    return model{list: l}
}

func (m model) Init() tea.Cmd {
    return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        h, v := docStyle.GetFrameSize()
        m.list.SetSize(msg.Width-h, msg.Height-v)

    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+c", "q", "esc":
            m.quitting = true
            return m, tea.Quit
        case "enter":
            if i, ok := m.list.SelectedItem().(item); ok {
                m.selected = i.name
            }
            m.quitting = true
            return m, tea.Quit
        }
    }

    var cmd tea.Cmd
    m.list, cmd = m.list.Update(msg)
    return m, cmd
}

func (m model) View() string {
    if m.quitting {
        return ""
    }
    return docStyle.Render(m.list.View())
}

func main() {
    p := tea.NewProgram(initialModel(), tea.WithAltScreen())
    finalModel, err := p.Run()
    if err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }

    m := finalModel.(model)
    if m.selected != "" {
        exec.Command("tmux", "switch-client", "-t", m.selected).Run()
    }
}
```

**tmux.conf binding**:
```bash
bind-key s display-popup -w 40% -h 50% -E "session-picker"
```

### Window Picker with Preview Pattern

```go
// Simplified window picker
package main

import (
    "fmt"
    "os"
    "os/exec"
    "strings"

    tea "github.com/charmbracelet/bubbletea"
)

type model struct {
    windows  []string
    cursor   int
    selected string
}

func getWindows() []string {
    out, _ := exec.Command("tmux", "list-windows", "-F", "#{window_index}: #{window_name}").Output()
    return strings.Split(strings.TrimSpace(string(out)), "\n")
}

func initialModel() model {
    return model{windows: getWindows()}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "q", "esc", "ctrl+c":
            return m, tea.Quit
        case "up", "k":
            if m.cursor > 0 {
                m.cursor--
            }
        case "down", "j":
            if m.cursor < len(m.windows)-1 {
                m.cursor++
            }
        case "enter":
            // Extract window index from "0: window-name"
            parts := strings.SplitN(m.windows[m.cursor], ":", 2)
            if len(parts) > 0 {
                m.selected = parts[0]
            }
            return m, tea.Quit
        }
    }
    return m, nil
}

func (m model) View() string {
    s := "Select Window:\n\n"
    for i, w := range m.windows {
        cursor := " "
        if m.cursor == i {
            cursor = ">"
        }
        s += fmt.Sprintf("%s %s\n", cursor, w)
    }
    s += "\n(enter to select, q to quit)"
    return s
}

func main() {
    p := tea.NewProgram(initialModel())
    finalModel, _ := p.Run()

    m := finalModel.(model)
    if m.selected != "" {
        exec.Command("tmux", "select-window", "-t", m.selected).Run()
    }
}
```

### Using Gum as Alternative

For simpler popup interactions, Charmbracelet's `gum` can be used directly:

```bash
# Session switcher with gum
bind-key s display-popup -w 40% -h 50% -E '\
    SESSION=$(tmux list-sessions -F "#S" | gum filter --placeholder "Pick session...") && \
    tmux switch-client -t "$SESSION"'

# File picker
bind-key f display-popup -d "#{pane_current_path}" -w 80% -h 80% -E '\
    FILE=$(find . -type f | gum filter) && \
    tmux send-keys "$FILE"'

# Git branch switcher
bind-key b display-popup -d "#{pane_current_path}" -w 60% -h 60% -E '\
    BRANCH=$(git branch | gum filter | tr -d " *") && \
    git checkout "$BRANCH"'
```

---

## References

- [Bubble Tea Documentation](https://pkg.go.dev/github.com/charmbracelet/bubbletea)
- [Bubble Tea GitHub](https://github.com/charmbracelet/bubbletea)
- [tmux Manual - display-popup](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [Charmbracelet Gum](https://github.com/charmbracelet/gum)
- [go-tmux Library](https://github.com/jubnzv/go-tmux)
- [tmux Popup Best Practices](https://willhbr.net/2023/02/07/dismissable-popup-shell-in-tmux/)
- [tmux-fzf Plugin](https://github.com/sainnhe/tmux-fzf)
- [Commands in Bubble Tea](https://charm.land/blog/commands-in-bubbletea/)
- [Building TUI Apps with Bubble Tea](https://leg100.github.io/en/posts/building-bubbletea-programs/)
