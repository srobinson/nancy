#!/usr/bin/env bash
# b_path:: src/nav/index.sh
# Navigation module loader
# ------------------------------------------------------------------------------
#
# Provides pane navigation primitives for Nancy orchestration.
#
# Functions:
#   nav::show_menu  - Show tmux menu for pane selection (mouse-enabled)
#   nav::zoom_pane  - Toggle zoom on current or specified pane
#   nav::is_zoomed  - Check if window is currently zoomed
#
# Usage:
#   source src/nav/index.sh
#   nav::show_menu       # Display navigation menu
#   nav::zoom_pane       # Toggle zoom
#
# ------------------------------------------------------------------------------

. "$NANCY_FRAMEWORK_ROOT/src/nav/nav.sh"
