<!-- b_path:: docs.llm/context7/tmux.md -->
# tmux - Terminal Multiplexer

## Introduction

tmux is a terminal multiplexer that enables multiple terminals to be created, accessed, and controlled from a single screen. It provides a robust client-server architecture where sessions can be detached from the terminal and continue running in the background, then later reattached from the same or different terminal. This makes tmux invaluable for remote work, long-running processes, and managing multiple terminal workflows simultaneously.

The project implements a comprehensive window management system with sessions, windows, and panes organized in a hierarchical structure. Sessions contain multiple windows, windows contain multiple panes, and each pane runs an independent pseudo-terminal. tmux supports extensive customization through configuration files, key bindings, options, and hooks. It provides features like copy mode, status bars, mouse support, multiple layouts, synchronized panes, and a rich command interface for automation and scripting. Modern additions include Sixel graphics support for inline images, OSC 8 hyperlinks for clickable URLs, enhanced Unicode handling with emoji and regional indicators, and improved terminal capability detection.

## Core APIs and Functions

### Session Management - Create and Find Sessions

Session creation and lookup functions form the foundation of tmux's session management system. Sessions are stored in a red-black tree indexed by name and can be looked up by name or numeric ID.

```c
#include "tmux.h"

// Create a new session with specific configuration
struct session *s;
const char *session_name = "dev-session";
const char *working_dir = "/home/user/project";
struct environ *env = environ_create();
struct options *opts = options_create(global_s_options);
struct termios *tio = NULL;

s = session_create("my", session_name, working_dir, env, opts, tio);
if (s == NULL) {
    fprintf(stderr, "Failed to create session\n");
    return 1;
}

// Session is now available in global sessions tree
// Find session by name
struct session *found = session_find("dev-session");
if (found != NULL) {
    printf("Found session: %s (id=%u)\n", found->name, found->id);
}

// Find session by ID string (format: "$123")
struct session *found_by_id = session_find_by_id_str("$0");
if (found_by_id != NULL) {
    printf("Found session by ID: %s\n", found_by_id->name);
}

// Check if session is still alive
if (session_alive(s)) {
    printf("Session is active\n");
}
```

### Window and Pane Management - Create Window Structure

Windows and panes provide the hierarchical structure for organizing terminal views. Windows are linked to sessions through winlinks, and panes subdivide windows.

```c
#include "tmux.h"

// Assuming we have a session 's'
struct session *s = session_find("dev-session");
struct winlink *wl;
struct window *w;
struct window_pane *wp;

// Find or create a window linked to the session
// Windows are accessed through winlinks (window links)
wl = winlink_find_by_index(&s->windows, 0);
if (wl == NULL) {
    // Create new window at index 0
    wl = winlink_add(&s->windows, 0);
}

w = wl->window;

// Find pane by window
RB_FOREACH(wp, window_pane_tree, &all_window_panes) {
    if (wp->window == w) {
        printf("Found pane %u in window %u\n", wp->id, w->id);
        break;
    }
}

// Find winlink by window ID
struct winlink *found_wl = winlink_find_by_window_id(&s->windows, w->id);
if (found_wl != NULL) {
    printf("Window index in session: %d\n", found_wl->idx);
}

// Iterate through all winlinks in a session
RB_FOREACH(wl, winlinks, &s->windows) {
    printf("Window %d: %s (%u panes)\n",
           wl->idx,
           wl->window->name,
           wl->window->references);
}
```

### Server Socket Creation and Client Connection

The server creates a Unix domain socket for client communication. Clients connect to this socket to send commands and receive updates.

```c
#include <sys/socket.h>
#include <sys/un.h>
#include "tmux.h"

// Server side: create socket
const char *socket_path = "/tmp/tmux-1000/default";
char *cause = NULL;
int server_fd;

server_fd = server_create_socket(CLIENT_DEFAULTSOCKET, &cause);
if (server_fd < 0) {
    fprintf(stderr, "Failed to create socket: %s\n", cause);
    free(cause);
    return 1;
}

// Socket is created with proper permissions (mode 0600 or 0700)
// and is ready to accept client connections
printf("Server socket created at: %s\n", socket_path);

// Client side: connect to server
struct event_base *base = event_base_new();
int client_fd;

client_fd = client_connect(base, socket_path, CLIENT_STARTSERVER);
if (client_fd < 0) {
    fprintf(stderr, "Failed to connect: %s\n", strerror(errno));
    event_base_free(base);
    return 1;
}

printf("Connected to server\n");
// Client can now send commands through the socket
```

### Command Execution - Define and Execute Commands

Commands in tmux follow a structured pattern with entry definitions, argument parsing, and execution handlers.

```c
#include "tmux.h"

// Command entry definition (from cmd-new-session.c)
const struct cmd_entry cmd_new_session_entry = {
    .name = "new-session",
    .alias = "new",
    .args = { "Ac:dDe:EF:f:n:Ps:t:x:Xy:", 0, -1, NULL },
    .usage = "[-AdDEPX] [-c start-directory] [-e environment] "
             "[-F format] [-n window-name] [-s session-name] "
             "[shell-command]",
    .target = { 't', CMD_FIND_SESSION, CMD_FIND_CANFAIL },
    .flags = CMD_STARTSERVER,
    .exec = cmd_new_session_exec
};

// Command execution example
static enum cmd_retval
cmd_new_session_exec(struct cmd *self, struct cmdq_item *item)
{
    struct args *args = cmd_get_args(self);
    struct client *c = cmdq_get_client(item);
    const char *session_name;

    // Parse arguments
    if (args_has(args, 's'))
        session_name = args_get(args, 's');
    else
        session_name = NULL;

    // Check for conflicting options
    if (args_has(args, 't') && args_count(args) != 0) {
        cmdq_error(item, "command given with target");
        return CMD_RETURN_ERROR;
    }

    // Execute command logic
    // ... (create session, attach client, etc.)

    return CMD_RETURN_NORMAL;
}

// Command lookup and execution
const struct cmd_entry *entry;
for (entry = cmd_table[0]; entry != NULL; entry++) {
    if (strcmp(entry->name, "new-session") == 0) {
        printf("Found command: %s (alias: %s)\n",
               entry->name, entry->alias);
        break;
    }
}
```

### Option Management - Set and Get Options

Options are stored in a red-black tree structure and support multiple types including strings, numbers, colors, and commands.

```c
#include "tmux.h"

// Create options tree
struct options *opts = options_create(NULL);  // No parent

// Set string option
options_set_string(opts, "status-right", 0, "%H:%M");

// Set number option
options_set_number(opts, "history-limit", 10000);

// Get option value
struct options_entry *o;
o = options_get(opts, "status-right");
if (o != NULL) {
    const char *value = options_get_string(opts, "status-right");
    printf("status-right: %s\n", value);
}

// Check if option exists
if (options_get(opts, "mouse") != NULL) {
    long long mouse = options_get_number(opts, "mouse");
    printf("Mouse is %s\n", mouse ? "on" : "off");
}

// Array options (for hooks, etc.)
options_array_set(opts, "hook-array", 0, "command-here");
options_array_set(opts, "hook-array", 1, "another-command");

// Iterate through all options
RB_FOREACH(o, options_tree, &opts->tree) {
    char *str = options_to_string(o, 0, 0);
    printf("%s = %s\n", o->name, str);
    free(str);
}

// Options inherit from parent
struct options *child_opts = options_create(opts);
// child_opts will inherit values from opts if not set
```

### Key Binding Management - Bind and Unbind Keys

Key bindings map keyboard input to command sequences. Bindings are organized in key tables (e.g., "root", "prefix", "copy-mode").

```c
#include "tmux.h"

// Bind a key to a command
struct key_table *table;
struct key_binding *bd;
struct cmd_list *cmdlist;

// Find or create key table
table = key_bindings_get_table("prefix", 1);  // 1 = create if missing

// Create command list
cmdlist = cmd_list_parse("split-window -h", NULL, 0, &error);
if (cmdlist == NULL) {
    fprintf(stderr, "Parse error: %s\n", error);
    free(error);
    return;
}

// Bind key (C-b %)
key_code key = KEYC_NONE;
key = key_string_lookup_string("C-b %");

bd = key_bindings_add(table, key, 0, cmdlist);
bd->note = xstrdup("Split window horizontally");

// Look up key binding
struct key_binding *found;
found = key_bindings_get(table, key);
if (found != NULL) {
    printf("Key bound to: %s\n",
           cmd_list_print(found->cmdlist, 0));
}

// Unbind key
key_bindings_remove(table, key);

// Default bindings example from key-bindings.c
// bind-key -T prefix % split-window -h
// bind-key -T prefix '"' split-window -v
// bind-key -T prefix c new-window
// bind-key -T prefix d detach-client
```

### Server Marked Pane - Track Selected Pane

The marked pane feature allows users to mark a pane for operations like swapping or joining.

```c
#include "tmux.h"

// Mark a pane (typically from user command)
struct session *s = session_find("dev-session");
struct winlink *wl = TAILQ_FIRST(&s->lastw);
struct window_pane *wp = wl->window->active;

// Set marked pane
server_set_marked(s, wl, wp);
printf("Marked pane %u in window %u\n", wp->id, wl->window->id);

// Check if a specific pane is marked
if (server_is_marked(s, wl, wp)) {
    printf("This pane is marked\n");
}

// Check if marked pane is still valid
if (server_check_marked()) {
    printf("Marked pane is valid\n");

    // Access marked pane through global marked_pane state
    extern struct cmd_find_state marked_pane;
    printf("Marked: session=%s, window=%d, pane=%u\n",
           marked_pane.s->name,
           marked_pane.wl->idx,
           marked_pane.wp->id);
}

// Clear marked pane
server_clear_marked();
```

### Configuration File Processing - Load and Execute Config

Configuration files contain tmux commands that are executed during startup or when explicitly sourced.

```c
#include "tmux.h"

// Example configuration file usage
// File: ~/.tmux.conf

/*
# Set prefix key to C-a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Enable mouse support
set -g mouse on

# Set status bar
set -g status-right "%H:%M"
set -g status-bg black
set -g status-fg white

# Key bindings
bind | split-window -h
bind - split-window -v

# Create default session
new-session -d -s work -n editor
neww -d -n console
selectw -t 1

# Set window options
setw -g monitor-activity on
setw -g aggressive-resize on
*/

// Load configuration programmatically
int cfg_status;
char *cfg_file = expand_path("~/.tmux.conf");
struct cmd_find_state fs;
struct cmdq_item *item;

cfg_status = load_cfg(cfg_file, &fs, NULL, NULL, &item);
if (cfg_status == -1) {
    fprintf(stderr, "Failed to load config: %s\n", cfg_file);
} else {
    printf("Config loaded successfully\n");
    // Commands are queued and will be executed
}

free(cfg_file);
```

### Environment Variable Management - Set and Get Environment

Environment variables can be set at the global, session, or pane level and are inherited by child processes.

```c
#include "tmux.h"

// Create environment
struct environ *env = environ_create();

// Set environment variables
environ_set(env, "EDITOR", 0, "vim");
environ_set(env, "TERM", 0, "screen-256color");
environ_set(env, "LANG", 0, "en_US.UTF-8");

// Get environment variable
const char *editor = environ_get(env, "EDITOR");
printf("EDITOR: %s\n", editor);

// Check if variable exists
struct environ_entry *entry;
entry = environ_find(env, "PATH");
if (entry != NULL) {
    printf("PATH is set to: %s\n", entry->value);
}

// Unset variable
environ_unset(env, "TEMP_VAR");

// Copy environment
struct environ *child_env = environ_create();
environ_copy(env, child_env);

// Update environment from system
extern char **environ;
environ_update(global_environ, env, environ);

// Push environment to pane's shell
struct window_pane *wp = /* get pane */;
environ_push(env);  // Updates process environment
```

### Control Mode - Programmatic Interface

Control mode provides a machine-readable interface for programmatic control of tmux, used by tools and IDEs.

```c
#include "tmux.h"

// Start tmux in control mode:
// $ tmux -C new-session -A -s control-session

// Control mode protocol (client sends/receives):
/*
// Input format (client -> server):
new-window -t mysession
split-window -h -t mysession:1

// Output format (server -> client):
%begin 1234567890 0 1
%output %1 window content here
%end 1234567890 0 1

// Notifications:
%session-changed $0 mysession
%window-add @1
%window-close @2
%pane-mode-changed %3
*/

// Server-side control notification example
void control_notify_window_close(struct session *s, struct window *w)
{
    struct client *c;

    TAILQ_FOREACH(c, &clients, entry) {
        if (c->session == s && (c->flags & CLIENT_CONTROL)) {
            control_write(c, "%%window-close @%u", w->id);
        }
    }
}

// Parse control command
struct cmd_list *cmdlist;
char *input = "split-window -h";
char *error = NULL;

cmdlist = cmd_list_parse(input, NULL, 0, &error);
if (cmdlist == NULL) {
    control_write(client, "%%error %s", error);
    free(error);
} else {
    // Execute command and send output
    cmdq_append(client, cmdq_get_command(cmdlist, &fs));
}
```

### Format String Expansion - Template Processing

Format strings enable dynamic text generation for status lines, command output, and display messages using variable substitution.

```c
#include "tmux.h"

// Common format variables:
// #{session_name} - current session name
// #{window_index} - window index
// #{pane_index} - pane index
// #{pane_current_path} - current working directory
// #{pane_pid} - process ID in pane
// #{host} - hostname
// #{?condition,true-text,false-text} - conditional

// Create format tree for expansion
struct format_tree *ft;
struct session *s = session_find("dev-session");
struct winlink *wl = s->curw;
struct window_pane *wp = wl->window->active;

ft = format_create(NULL, NULL, FORMAT_NONE, 0);
format_defaults(ft, NULL, s, wl, wp);

// Add custom formats
format_add(ft, "custom_var", "%s", "custom_value");
format_add(ft, "uptime", "%ld", time(NULL) - start_time.tv_sec);

// Expand format string
const char *template = "#{session_name}:#{window_index}.#{pane_index}";
char *expanded = format_expand(ft, template);
printf("Expanded: %s\n", expanded);  // Output: "dev-session:1.0"

// Complex conditional format
template = "#{?mouse,Mouse ON,Mouse OFF} | "
           "#{?pane_synchronized,SYNC,} | "
           "Pane #{pane_id}";
expanded = format_expand(ft, template);
printf("%s\n", expanded);

// Status line format example
template = "#[fg=green]#S #[fg=yellow]#I:#W #[fg=cyan]%H:%M";
expanded = format_expand(ft, template);

format_free(ft);
free(expanded);
```

### Input Key Processing - Handle Keyboard Input

Keyboard input is processed through key codes with modifiers, supporting complex key sequences and mouse events.

```c
#include "tmux.h"

// Key code structure (from tmux.h)
// Modifiers: KEYC_META, KEYC_CTRL, KEYC_SHIFT
// Flags: KEYC_LITERAL, KEYC_KEYPAD, KEYC_CURSOR

// Parse key string to key code
key_code key;
key = key_string_lookup_string("C-b");  // Ctrl+b
if (key != KEYC_UNKNOWN) {
    printf("Key code: 0x%llx\n", key);
}

// Process key combinations
key = key_string_lookup_string("M-S-left");  // Alt+Shift+Left
key = key_string_lookup_string("F1");
key = key_string_lookup_string("MouseDown1");

// Check key properties
if (key & KEYC_CTRL) {
    printf("Control modifier detected\n");
}

if (KEYC_IS_MOUSE(key)) {
    printf("Mouse event\n");
}

if (KEYC_IS_UNICODE(key)) {
    wchar_t ch = (key & KEYC_MASK_KEY);
    printf("Unicode character: %lc\n", ch);
}

// Send keys to pane
struct window_pane *wp = /* get active pane */;
key_code keys[] = { 'l', 's', '\r' };  // Type "ls" and Enter

for (size_t i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
    input_key_pane(wp, keys[i], NULL);
}

// Key string conversion
const char *keystr = key_string_lookup_key(key, 1);
printf("Key string: %s\n", keystr);
```

### Layout Management - Arrange Panes

Layouts control how panes are arranged within a window, supporting multiple predefined layouts and custom configurations.

```c
#include "tmux.h"

// Available layouts:
// LAYOUT_EVEN_HORIZONTAL - panes evenly split horizontally
// LAYOUT_EVEN_VERTICAL - panes evenly split vertically
// LAYOUT_MAIN_HORIZONTAL - main pane on top, others below
// LAYOUT_MAIN_VERTICAL - main pane on left, others right
// LAYOUT_TILED - panes in tiled grid

// Apply layout to window
struct window *w = /* get window */;
const char *layout_name = "main-vertical";

// Find layout by name
int layout_type = layout_set_lookup(layout_name);
if (layout_type == -1) {
    fprintf(stderr, "Unknown layout: %s\n", layout_name);
    return;
}

// Apply layout
layout_set_select(w, layout_type);
printf("Applied %s layout to window %u\n", layout_name, w->id);

// Get current layout
struct layout_cell *lc = w->layout_root;
char *layout_str = layout_dump(lc);
printf("Current layout: %s\n", layout_str);
free(layout_str);

// Custom layout from string
// Format: checksum,width,height,x,y{pane-info}[layout-cells]
const char *custom_layout =
    "c550,159x48,0,0{79x48,0,0,0,79x48,80,0[79x24,80,0,1,79x23,80,25,2]}";

int result = layout_parse(w, custom_layout);
if (result == 0) {
    printf("Custom layout applied\n");
    window_resize(w, w->sx, w->sy);
}

// Next/previous layout
layout_set_next(w);   // Cycle to next layout
layout_set_previous(w);  // Cycle to previous layout
```

### Image Support - Sixel Graphics

tmux supports Sixel graphics for displaying inline images in terminal panes when compiled with ENABLE_SIXEL. Images are managed per screen and have fallback text representations.

```c
#include "tmux.h"

// Images are stored in a screen's image list
// Maximum of 20 images per screen (MAX_IMAGE_COUNT)
struct screen *s = /* get screen */;

// Images are created through terminal escape sequences (Sixel protocol)
// but can be managed programmatically

// Check if an image exists on a screen
struct image *im;
TAILQ_FOREACH(im, &s->images, entry) {
    printf("Image at x=%u, y=%u, size=%ux%u\n",
           im->px, im->py, im->sx, im->sy);

    // Each image has a fallback text representation
    if (im->fallback != NULL) {
        printf("Fallback: %s\n", im->fallback);
    }
}

// Free all images on a screen (returns 1 if redraw needed)
if (image_free_all(s)) {
    printf("Images cleared, redraw required\n");
}

// Images are automatically saved/restored with alternate screen
// This preserves graphics when switching between normal and alternate screens

// Example of receiving Sixel data via escape sequence:
// ESC P q "Sixel data here" ESC \
// The input parser automatically creates and manages images

// Images have coordinates and dimensions
struct image *current_image = TAILQ_FIRST(&s->images);
if (current_image != NULL) {
    printf("First image: pos=(%u,%u) size=%ux%u\n",
           current_image->px, current_image->py,
           current_image->sx, current_image->sy);
}

// Scrollback behavior: images scroll with content and are freed
// when they exceed the maximum count or scroll out of history
```

### Hyperlinks - OSC 8 URL Support

tmux implements OSC 8 hyperlink support, allowing terminals to display clickable URLs with optional IDs for grouping related links.

```c
#include "tmux.h"

// Hyperlinks are stored in a tree structure per screen
// Each URI gets a unique internal identifier
// Maximum 5000 hyperlinks (MAX_HYPERLINKS)

// Hyperlink structure
struct hyperlinks *hl = hyperlinks_init();

// Hyperlinks are created via OSC 8 escape sequences:
// OSC 8 ; params ; URI ST
// Format: ESC ] 8 ; id=identifier ; https://example.com ESC \

// Get a hyperlink by inner identifier
struct hyperlinks_uri *uri;
uri = hyperlinks_get(hl, inner_id);
if (uri != NULL) {
    printf("URI: %s\n", uri->uri);
    printf("Internal ID: %s\n", uri->internal_id);
    printf("External ID: %s\n", uri->external_id);
}

// Hyperlinks support two types:
// 1. Named hyperlinks - share the same internal ID and can be reused
//    Multiple occurrences of the same URI with the same ID reference the same link
// 2. Anonymous hyperlinks - each is unique even if URI is the same
//    Created when no ID is provided in OSC 8 sequence

// The hyperlink system maintains:
// - tree: mapping by URI and internal ID for named links
// - by_inner: mapping by internal identifier for quick lookup
// - external_id: unique ID sent to the terminal
// - global list: all hyperlinks across all screens

// Store a hyperlink in a screen (via terminal output)
// This is typically done by the input parser when receiving OSC 8
const char *uri_text = "https://github.com/tmux/tmux";
const char *id = "tmux-repo";  // or "" for anonymous

// The hyperlink is associated with screen grid cells
// Each cell can reference a hyperlink by its inner number
// When rendering, tmux sends OSC 8 sequences to the terminal

// Hyperlinks are reference counted
hyperlinks_ref(hl);    // Increment reference
hyperlinks_free(hl);   // Decrement and free if zero

// Hyperlinks are automatically managed during:
// - Text output (cells store hyperlink inner IDs)
// - Copy mode (preserves hyperlinks)
// - Screen resize and scrollback
```

## Summary and Integration

tmux serves as a powerful terminal workspace manager for developers, system administrators, and power users who need to maintain multiple terminal sessions and persist work across disconnections. The primary use cases include remote server management where sessions can survive network interruptions, development environments with multiple editor/compiler/debugger panes, long-running tasks that outlive terminal connections, and pair programming with shared session access. Its client-server architecture ensures that work continues uninterrupted even when disconnected, making it essential for reliable remote work.

Integration patterns with tmux include embedding it in development workflows through IDE plugins and terminal emulators, programmatic control via the control mode protocol for automated testing and deployment, configuration management through version-controlled tmux.conf files, and scripting with tmux commands for session initialization and workspace setup. The project exposes both a command-line interface for interactive use and a C API for extending functionality. Key integration points include the Unix domain socket for client-server communication, the format string system for status customization, hooks for event-driven automation, and the extensive command set that covers session/window/pane management, key bindings, options, and copy mode operations. Modern features extend tmux's capabilities with Sixel graphics support for displaying inline images, OSC 8 hyperlinks for clickable URLs in terminal output, enhanced Unicode handling including emoji modifiers and regional indicators, and improved terminal capability detection for better compatibility with contemporary terminal emulators. These components combine to create a flexible, extensible terminal multiplexer suitable for diverse workflow requirements from traditional command-line work to modern rich-content terminal applications.
