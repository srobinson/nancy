<!-- b_path:: docs.llm/context7/gum.md -->
# Gum - Glamorous Shell Scripts

Gum is a command-line tool for creating glamorous shell scripts and interactive terminal applications. Built on the Charm Bubbles TUI framework and Lip Gloss styling library, it provides ready-to-use components for user input, selection, confirmation, filtering, and text formatting without requiring Go programming knowledge. Gum allows shell script developers to build sophisticated interactive workflows through simple CLI commands that can be piped together or combined with standard Unix tools.

The tool serves as a bridge between traditional shell scripting and modern terminal user interfaces, offering components like text inputs, multi-select lists, fuzzy filters, spinners, pagers, and styled text rendering. Each command outputs to stdout and can be integrated seamlessly into existing shell scripts, making it ideal for creating commit helpers, file selectors, configuration wizards, and interactive CLI workflows.

## Commands and Functions

### Input - Single-line Text Prompt

Prompts the user for a single line of text input with optional placeholder text and password masking. The entered text is sent to stdout when the user presses Enter.

```bash
# Basic input
gum input --placeholder "Enter your name" > name.txt

# Password input with masking
gum input --password --placeholder "Enter password" > password.txt

# Input with custom styling and width
gum input --cursor.foreground "#FF0" \
          --prompt.foreground "#0FF" \
          --placeholder "What's up?" \
          --prompt "* " \
          --width 80 \
          --value "Not much, hby?"

# Using environment variables for configuration
export GUM_INPUT_CURSOR_FOREGROUND="#FF0"
export GUM_INPUT_PLACEHOLDER="What's up?"
gum input > response.txt
```

### Choose - Select from List of Options

Presents a list of options for the user to choose from, with support for single or multiple selections. Unlike filter, this provides a simple list without fuzzy matching.

```bash
# Single choice
CARD=$(gum choose --height 15 {{A,K,Q,J},{10..2}}" "{♠,♥,♣,♦})
echo "Was your card the $CARD?"

# Multiple selections with limit
gum choose --limit 5 "Strawberry" "Banana" "Cherry" "Grape" "Apple" "Orange"

# Unlimited selections
cat foods.txt | gum choose --no-limit --header "Grocery Shopping"

# Pre-select options
gum choose --selected "Apple" --selected "Banana" \
  "Apple" "Banana" "Cherry" "Date" "Elderberry"

# Custom styling
gum choose --cursor "> " \
           --cursor.foreground 212 \
           --selected.foreground 212 \
           "Option 1" "Option 2" "Option 3"
```

### Confirm - Yes/No Confirmation

Asks the user to confirm an action with affirmative or negative options. Returns exit code 0 for affirmative, 1 for negative, making it ideal for conditional execution in scripts.

```bash
# Simple confirmation with default prompt
gum confirm && rm file.txt || echo "File not removed"

# Custom affirmative/negative text
gum confirm "Delete all files?" \
  --affirmative="Yes, delete!" \
  --negative="No, keep them"

# Use in conditional chains
if gum confirm "Deploy to production?"; then
  ./deploy.sh
else
  echo "Deployment cancelled"
fi

# With custom styling
gum confirm "Continue?" \
  --selected.foreground=212 \
  --unselected.foreground=240
```

### Filter - Fuzzy Search and Filter

Provides fuzzy searching to filter and select items from a list. Supports multiple selections, exact or fuzzy matching, and can read from stdin or files.

```bash
# Filter from file
echo "Strawberry" >> flavors.txt
echo "Banana" >> flavors.txt
echo "Cherry" >> flavors.txt
gum filter < flavors.txt > selection.txt

# Multiple selections with limit
cat flavors.txt | gum filter --limit 2

# Unlimited selections
cat flavors.txt | gum filter --no-limit

# Use for file selection in editor
$EDITOR $(gum filter)

# Filter git branches
git branch | cut -c 3- | gum filter | xargs git checkout

# With custom styling and header
gum filter --header "Select files:" \
           --placeholder "Search..." \
           --indicator "→ " \
           --match.foreground 212 \
           < file_list.txt
```

### Write - Multi-line Text Input

Prompts for multi-line text input using a text area interface. Text entry is completed with Ctrl+D (Enter for single line mode) and can be aborted with Ctrl+C or Escape.

```bash
# Basic multi-line input
gum write > story.txt

# With placeholder text
gum write --placeholder "Enter your story here..." > output.txt

# Custom dimensions
gum write --width 80 --height 20 > article.txt

# Git commit with write
git commit -m "$(gum input --placeholder "Summary")" \
           -m "$(gum write --placeholder "Details")"

# Open external editor
gum write --show-cursor-line \
          --char-limit 500 \
          --base-style "foreground:212" > description.txt
```

### Spin - Display Spinner During Command Execution

Displays a spinner while running a command or script. The spinner automatically stops when the command completes. Use `--show-output` to view the command's output.

```bash
# Basic spinner with command
gum spin --spinner dot --title "Buying Bubble Gum..." -- sleep 5

# Show command output
gum spin --spinner line --title "Installing packages..." \
         --show-output -- npm install

# Different spinner styles
gum spin --spinner globe --title "Processing..." -- ./long_task.sh
gum spin --spinner moon --title "Loading..." -- curl https://api.example.com

# Available spinner types: line, dot, minidot, jump, pulse, points,
# globe, moon, monkey, meter, hamburger

# With alignment
gum spin --spinner dot --title "Working..." --align right -- make build
```

### Style - Apply Colors and Formatting

Applies styling to text including colors, borders, alignment, padding, and margins using Lip Gloss. Supports a comprehensive set of styling options for creating visually appealing terminal output.

```bash
# Simple styled text
gum style --foreground 212 "Bubble Gum"

# With border and layout
gum style \
  --foreground 212 --border-foreground 212 --border double \
  --align center --width 50 --margin "1 2" --padding "2 4" \
  'Bubble Gum (1¢)' 'So sweet and so fresh!'

# Multiple text formatting
gum style --bold --foreground 99 "Important Message"
gum style --italic --underline --foreground 212 "Styled Text"

# Create bordered boxes
BOX=$(gum style --border rounded --border-foreground 57 \
               --padding "1 2" --width 30 "Box Content")
echo "$BOX"
```

### Join - Combine Text Horizontally or Vertically

Joins multiple text elements vertically or horizontally, useful for building complex layouts and combining styled elements.

```bash
# Horizontal join
I=$(gum style --padding "1 5" --border double --border-foreground 212 "I")
LOVE=$(gum style --padding "1 4" --border double --border-foreground 57 "LOVE")
gum join --horizontal "$I" "$LOVE"

# Vertical join
HEADER=$(gum style --bold --foreground 212 "Header")
CONTENT=$(gum style --foreground 240 "Content here")
gum join --vertical "$HEADER" "$CONTENT"

# Complex layout with alignment
I_LOVE=$(gum join "$I" "$LOVE")
BUBBLE_GUM=$(gum join "$BUBBLE" "$GUM")
gum join --align center --vertical "$I_LOVE" "$BUBBLE_GUM"
```

### Pager - Scroll Through Content

Displays content in a scrollable viewport with line numbers and search functionality, similar to less or more.

```bash
# Basic paging
gum pager < README.md

# Custom dimensions
gum pager --height 20 --width 80 < large_file.txt

# With line numbers
gum pager --show-line-numbers < code.go

# Soft wrap long lines
gum pager --soft-wrap < log_file.txt

# Custom styling
gum pager --match-style "foreground:212" \
          --match-highlight-style "foreground:212,bold" \
          < document.md
```

### Format - Process and Style Text

Formats and processes text including markdown rendering, code syntax highlighting, template processing, and emoji rendering.

```bash
# Format markdown
gum format -- "# Gum Formats" "- Markdown" "- Code" "- Template" "- Emoji"
echo "# Title\n## Subtitle\n- List item" | gum format

# Syntax highlight code
cat main.go | gum format -t code

# Process templates with styling
echo '{{ Bold "Tasty" }} {{ Italic "Bubble" }} {{ Color "99" "0" " Gum " }}' \
  | gum format -t template

# Render emojis
echo 'I :heart: Bubble Gum :candy:' | gum format -t emoji

# With custom theme
gum format --theme dark < document.md
gum format --theme light --language go < code.go
```

### Table - Render Tabular Data

Renders CSV or tabular data in an interactive table format, allowing users to navigate and select rows.

```bash
# Basic table from CSV
gum table <<< "Flavor,Price\nStrawberry,$0.50\nBanana,$0.99\nCherry,$0.75"

# Select row and extract field
gum table < data.csv | cut -d ',' -f 1

# From file with custom separator
gum table --separator="|" --file data.txt

# With custom styling
gum table --columns "Name,Age,City" \
          --widths 20,10,15 \
          --border rounded \
          --border.foreground 212 < users.csv

# Print without selection
gum table --print < report.csv
```

### File - Navigate and Select Files

Provides a file manager interface for navigating directories and selecting files.

```bash
# Pick file from current directory
gum file

# Pick from specific directory
gum file $HOME

# Open in editor
$EDITOR $(gum file)

# Select from specific path
gum file /etc/

# With custom height
gum file --height 20 ~/projects/

# Show all files including hidden
gum file --all ~/Documents/
```

### Log - Structured Logging

Logs messages with different severity levels and structured data using the charmbracelet/log library.

```bash
# Basic log messages
gum log --level info "Application started"
gum log --level error "Failed to connect to database"

# Structured logging
gum log --structured --level debug "Creating file..." name file.txt
gum log --structured --level error "Unable to create file." name file.txt

# With timestamp
gum log --time rfc822 --level info "Processing request"
gum log --time "2006-01-02 15:04:05" --level warn "High memory usage"

# Different formatters
gum log --formatter json --structured --level info "Event occurred" user "john"
gum log --formatter logfmt --structured --level debug "Query executed" duration 45

# Log to file
gum log --file app.log --level error "Critical error occurred"

# Custom styling
gum log --level.foreground 212 --message.bold true \
        --level info "Styled log message"
```

### Version-Check - Semantic Version Validation

Checks if the current Gum version matches a given semantic version constraint. Returns exit code 0 if the constraint is satisfied, otherwise exits with an error. Useful for ensuring minimum version requirements in scripts.

```bash
# Check if version is at least 0.15
gum version-check '>= 0.15.0'

# Check version with pessimistic constraint
gum version-check '~> 0.15'

# Use in scripts to ensure minimum version
if gum version-check '>= 0.14.0'; then
  echo "Gum version is compatible"
else
  echo "Please upgrade Gum to at least v0.14.0"
  exit 1
fi

# Check exact version
gum version-check '= 0.15.0'

# Check version range
gum version-check '>= 0.14.0, < 1.0.0'
```

## Integration Patterns and Use Cases

Gum excels at creating interactive shell scripts and enhancing terminal workflows. Common use cases include building commit helpers that guide users through conventional commit formatting, creating file and branch selectors for git operations, designing configuration wizards for applications, and building interactive menus for system administration tasks. The tool integrates seamlessly with existing shell scripts by outputting results to stdout, allowing commands to be chained with pipes, redirected to files, or captured in variables for further processing.

The modular design allows components to be combined creatively: use `filter` to select files then pipe to `confirm` for verification, chain `input` and `write` for multi-stage data collection, or combine `style` and `join` to create sophisticated terminal layouts. Environment variables provide consistent styling across commands, while the exit codes from `confirm` enable conditional logic. Gum transforms traditional shell scripts into polished, user-friendly interfaces while maintaining the simplicity and power of Unix command composition. Real-world integrations include tmux session managers, password selectors, package uninstallers, git workflow helpers, and custom CLI tools that previously required complex ncurses programming or compiled languages.
