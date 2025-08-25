#!/bin/bash
# GitHub Provider for REPOCLI
# Direct 1:1 mapping to GitHub CLI (gh)

# Execute GitHub commands
github_execute() {
    debug_log "GitHub provider executing: gh $*"
    
    # Check if gh CLI is available
    if ! check_cli_tool "gh"; then
        exit 1
    fi
    
    # Direct passthrough to gh CLI
    exec gh "$@"
}