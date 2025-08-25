#!/bin/bash
# =============================================================================
# GITHUB PROVIDER - SOURCE OF TRUTH DOCUMENTATION
# =============================================================================
# This file serves as the authoritative reference for all GitHub CLI commands
# that REPOCLI supports. Each function documents the expected behavior, 
# parameters, and examples that other providers should implement.
#
# Function naming convention: rca_{command}_{subcommand}() (repocli action prefix)
# This ensures consistent function names across all providers for easier maintenance.

# =============================================================================
# PM SYSTEM ERROR HANDLING COMPATIBILITY REQUIREMENTS
# =============================================================================
# Based on analysis of .claude/scripts/pm/ and .claude/commands/pm/
# These patterns are CRITICAL for PM system functionality across all providers
#
# PM COMMAND DEPENDENCIES:
# - if gh auth status &> /dev/null; then  # Silent auth check (exit code 0/1)
# - $(gh auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')  # Output parsing
# - gh --version | head -1  # Version display
# - gh issue create --json number -q .number  # JSON extraction
# - if gh extension list | grep -q "yahsan2/gh-sub-issue"; then  # Extension detection
# - command -v gh &> /dev/null  # CLI availability check
# - gh repo view --json nameWithOwner -q .nameWithOwner  # Repository info extraction
# - gh --version | head -1  # Version info for status display
#
# CRITICAL REQUIREMENTS FOR ALL PROVIDERS:
# - Exit codes MUST match GitHub CLI exactly (PM uses exit status for flow control)
# - Error messages MUST be parseable by grep patterns PM expects
# - Silent operations (&> /dev/null) MUST work identically
# - JSON output format MUST be consistent for PM's jq queries
# - Extension detection MUST return greppable output
# - Authentication status parsing MUST match exact format: "Logged in to [hostname] as [username]"
#
# DEBUG MODE STRATEGY:
# - REPOCLI_DEBUG=1: Show raw provider output to stderr (non-blocking)
# - Normal mode: Show GitHub-compatible output for PM parsing
# - Debug format: [DEBUG] Provider raw: <output> followed by GitHub-compatible output
#
# KEY PM WORKFLOW PATTERNS:
# 1. /pm:init - Silent auth checks, extension installation, CLI validation
# 2. /pm:epic-sync - Issue creation with JSON extraction, label management
# 3. /pm:status - Repository info queries, authentication status parsing
# 4. /pm:issue-start - Individual issue operations with exit code dependencies
#
# ERROR HANDLING PATTERNS FOR PM SYSTEM COMPATIBILITY
# (Complete patterns and analysis delegated to Task #22)
#
# TESTING REQUIREMENTS FOR TASK #6:
# - Test basic error consistency (exit codes, silent operations)
# - Validate wrapper doesn't break PM-style error detection
# - Test debug mode functionality (REPOCLI_DEBUG=1)
# - Verify stderr vs stdout separation works correctly
#
# IMPLEMENTATION GUIDANCE:
# - Detailed error mapping patterns will be provided by Task #22
# - Focus on testing framework and basic error passthrough
# - Error mapping implementation details: See Task #22 deliverables

# Execute GitHub commands - main entry point
github_execute() {
    debug_log "GitHub provider executing: gh $*"
    
    # Check if gh CLI is available
    if ! check_cli_tool "gh"; then
        exit 1
    fi
    
    # Direct passthrough to gh CLI - GitHub provider maintains 1:1 compatibility
    # The rca_ functions below are for documentation purposes only
    exec gh "$@"
}

# The functions below this point are never executed - they're documentation only
return 0

#
# RCA_ FUNCTION DOCUMENTATION (FOR OTHER PROVIDERS TO IMPLEMENT)
# ============================================================
# The following rca_ functions are for documentation purposes only.
# They show other providers what GitHub CLI commands need to be implemented
# and demonstrate different --repocli-can-handle pattern matching techniques.
# The GitHub provider itself uses direct passthrough (exec gh "$@") above.
#

#
# AUTHENTICATION COMMANDS
#

# gh auth status - Check authentication status
# Usage: repocli auth status
# Returns: Authentication status and current user info
# Pedagogical example: Exact string matching
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:init (silent check), /pm:status (parsing)
# PM patterns: if repocli auth status &> /dev/null; then
# PM parsing: $(repocli auth status 2>&1 | grep -o 'Logged in to [^ ]*')
# Expected output: "Logged in to github.com as username" or error with exit 1
# Error detection: status only
# CRITICAL: Silent mode (&> /dev/null) must work for flow control
rca_auth_status() {
    # Self-registration: exact string match pattern
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "auth status" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough to gh auth status
    exec gh auth status "$@"
}

# gh auth login - Interactive login to GitHub
# Usage: repocli auth login [--hostname HOST] [--web]
# Parameters:
#   --hostname: GitHub hostname (for GitHub Enterprise)
#   --web: Use web browser for authentication
# Returns: Success/failure of authentication
# Pedagogical example: Exact string matching with error handling
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:init (interactive authentication setup)
# PM patterns: gh auth login (called when auth status fails)
# Expected output: Interactive authentication flow with proper exit codes
# Error detection: not yet analyzed
# CRITICAL: Must support interactive flow and return proper exit status
rca_auth_login() {
    # Self-registration: exact string match with validation
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        # Validate we have at least 2 arguments for comparison
        [[ $# -ge 2 && "$1 $2" == "auth login" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough to gh auth login
    exec gh auth login "$@"
}

#
# ISSUE MANAGEMENT COMMANDS  
#

# gh issue view - Display issue details
# Usage: repocli issue view NUMBER [--json FIELDS] [-q QUERY] [--web] [--comments]
# Parameters:
#   NUMBER: Issue number to view
#   --json: Return JSON output with specified fields
#   -q: jq query to apply to JSON output
#   --web: Open issue in web browser
#   --comments: Include issue comments
# Returns: Issue details in text or JSON format
# Pedagogical example: Bash regex pattern matching
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:epic-sync (fallback task list building)
# PM patterns: gh issue view {epic_number} --json body -q .body
# Expected output: Must support JSON field extraction for issue body content
# Error detection: not yet analyzed
# CRITICAL: JSON queries must return exact field values for content manipulation
rca_issue_view() {
    # Self-registration: regex pattern example for pedagogy
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        # Bash regex: "issue" followed by whitespace and "view"
        [[ "$1 $2" =~ ^issue[[:space:]]view$ ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - gh handles all parameters natively
    exec gh issue view "$@"
}

# gh issue create - Create new issue
# Usage: repocli issue create [--title TITLE] [--body BODY] [--body-file FILE] [--label LABELS] [--labels LABELS] [--assignee USER] [--parent NUMBER]
# Parameters:
#   --title: Issue title
#   --body: Issue description
#   --body-file: File containing issue description (use "-" for stdin)
#   --label: Comma-separated list of labels (single flag)
#   --labels: Comma-separated list of labels (multiple uses)
#   --assignee: Username to assign (use "@me" for self-assignment)
#   --parent: Parent issue number for creating sub-issues
# Returns: URL of created issue, or JSON with --json flag
# Pedagogical example: Case pattern matching
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:epic-sync (epic creation), /pm:issue-create
# PM patterns: epic_number=$(repocli issue create --json number -q .number)
# Expected output: Must support --json parameter and return valid JSON with number field
# Error detection: not yet analyzed
# CRITICAL: JSON extraction with -q .number must return only the issue number
rca_issue_create() {
    # Self-registration: case pattern example for pedagogy
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        # Case pattern matching (alternative to string comparison)
        case "$1 $2" in
            "issue create") return 0 ;;
            *) return 1 ;;
        esac
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh issue create "$@"
}

# gh issue edit - Edit existing issue
# Usage: repocli issue edit NUMBER [--title TITLE] [--body-file FILE] [--add-label LABEL] [--remove-label LABEL] [--add-assignee USER]
# Parameters:
#   NUMBER: Issue number to edit
#   --title: New issue title
#   --body-file: File containing new description (use "-" for stdin)
#   --add-label: Add label to issue
#   --remove-label: Remove label from issue
#   --add-assignee: Add assignee to issue (use "@me" for self-assignment)
# Returns: Success status
# Pedagogical example: Glob pattern matching
rca_issue_edit() {
    # Self-registration: glob pattern example for pedagogy
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        # Bash globbing: "issue" + any word starting with "e"
        case "$1 $2" in
            "issue e"*) [[ "$2" == "edit" ]] && return 0 || return 1 ;;
            *) return 1 ;;
        esac
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh issue edit "$@"
}

# gh issue close - Close issue
# Usage: repocli issue close NUMBER [--comment COMMENT] [-c COMMENT] [--reason REASON]
# Parameters:
#   NUMBER: Issue number to close
#   --comment/-c: Add comment when closing
#   --reason: Reason for closing (completed, not_planned)
# Returns: Success status
rca_issue_close() {
    # Self-registration: handle issue close commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue close" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh issue close "$@"
}

# gh issue reopen - Reopen closed issue
# Usage: repocli issue reopen NUMBER [--comment COMMENT] [-c COMMENT]
# Parameters:
#   NUMBER: Issue number to reopen
#   --comment/-c: Add comment when reopening
# Returns: Success status
rca_issue_reopen() {
    # Self-registration: handle issue reopen commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue reopen" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh issue reopen "$@"
}

# gh issue list - List repository issues
# Usage: repocli issue list [--label LABELS] [--limit N] [--json FIELDS] [--parent NUMBER] [--child]
# Parameters:
#   --label: Filter by labels (can be comma-separated or used multiple times)
#   --limit: Maximum number of issues to list
#   --json: Return JSON output with specified fields
#   --parent: Filter by parent issue number
#   --child: Show only child issues
# Returns: List of issues in text or JSON format
rca_issue_list() {
    # Self-registration: handle issue list commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue list" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh issue list "$@"
}

# gh issue comment - Add comment to issue
# Usage: repocli issue comment NUMBER [--body-file FILE]
# Parameters:
#   NUMBER: Issue number to comment on
#   --body-file: File containing comment text (use "-" for stdin)
# Returns: Success status
rca_issue_comment() {
    # Self-registration: handle issue comment commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue comment" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh issue comment "$@"
}

# gh issue link - Link issues with relationships
# Usage: repocli issue link NUMBER TARGET [--type TYPE]
# Parameters:
#   NUMBER: Source issue number
#   TARGET: Target issue number to link to
#   --type: Relationship type (parent, child, related, blocks, blocked-by)
# Returns: Success status
# Note: GitHub uses task lists and mentions for relationships
rca_issue_link() {
    # Self-registration: handle issue link commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue link" ]] && return 0 || return 1
    fi
    
    # GitHub: Relationship linking through comments and task lists
    exec gh issue link "$@"
}

# gh issue unlink - Unlink related issues
# Usage: repocli issue unlink NUMBER TARGET
# Parameters:
#   NUMBER: Source issue number
#   TARGET: Target issue number to unlink from
# Returns: Success status
rca_issue_unlink() {
    # Self-registration: handle issue unlink commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue unlink" ]] && return 0 || return 1
    fi
    
    # GitHub: Relationship unlinking
    exec gh issue unlink "$@"
}

#
# REPOSITORY OPERATIONS
#

# gh repo view - Display repository information
# Usage: repocli repo view [--json FIELDS] [-q QUERY] [--web]
# Parameters:
#   --json: Return JSON output with specified fields
#   -q: jq query to apply to JSON output
#   --web: Open repository in web browser
# Returns: Repository details in text or JSON format
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:epic-sync (repository info extraction)
# PM patterns: repo=$(repocli repo view --json nameWithOwner -q .nameWithOwner)
# Expected output: Must support --json nameWithOwner parameter with -q .nameWithOwner
# Error detection: not yet analyzed
# CRITICAL: JSON extraction must return only the owner/repo string for URL construction
rca_repo_view() {
    # GitHub: Direct passthrough - gh handles all parameters natively
    exec gh repo view "$@"
}

#
# LABEL MANAGEMENT COMMANDS
#

# gh label create - Create repository label
# Usage: repocli label create LABEL [--color COLOR] [--description DESC] [--force]
# Parameters:
#   LABEL: Label name
#   --color/-c: Label color (hex code)
#   --description/-d: Label description
#   --force/-f: Overwrite existing label
# Returns: Success status
# Pedagogical example: Advanced regex with alternation
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:epic-sync (label creation for epics)
# PM patterns: Direct label creation with --color and --description parameters
# Expected output: Success confirmation or error with proper exit code
# Error detection: not yet analyzed
# CRITICAL: Must handle label creation failure gracefully without breaking epic sync
rca_label_create() {
    # Self-registration: advanced regex pattern for pedagogy
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        # Advanced regex: "label" + (create|add|new) using extended regex
        if [[ "$1" == "label" ]] && [[ "$2" =~ ^(create|add|new)$ ]]; then
            return 0
        fi
        return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh label create "$@"
}

# gh label list - List repository labels
# Usage: repocli label list [--json FIELDS] [-q QUERY] [--limit N] [--search TERM] [--web] [--sort FIELD] [--order ORDER]
# Parameters:
#   --json: Return JSON output with specified fields
#   -q: jq query to apply to JSON output
#   --limit/-L: Maximum number of labels to list
#   --search/-S: Search term to filter labels
#   --web/-w: Open labels page in web browser
#   --sort: Sort field (name, description, created)
#   --order: Sort order (asc, desc)
# Returns: List of labels in text or JSON format
rca_label_list() {
    # Self-registration: handle label list commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "label list" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh label list "$@"
}

# gh label edit - Edit existing label
# Usage: repocli label edit LABEL [--name NEW_NAME] [--color COLOR] [--description DESC]
# Parameters:
#   LABEL: Current label name
#   --name/-n: New label name
#   --color/-c: New label color (hex code)
#   --description/-d: New label description
# Returns: Success status
rca_label_edit() {
    # Self-registration: handle label edit commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "label edit" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh label edit "$@"
}

# gh label delete - Delete repository label
# Usage: repocli label delete LABEL [--yes]
# Parameters:
#   LABEL: Label name to delete
#   --yes: Skip confirmation prompt
# Returns: Success status
rca_label_delete() {
    # Self-registration: handle label delete commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "label delete" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh label delete "$@"
}

# gh label clone - Clone labels from another repository
# Usage: repocli label clone SOURCE_REPO [--force]
# Parameters:
#   SOURCE_REPO: Repository to clone labels from (owner/name format)
#   --force: Overwrite existing labels
# Returns: Success status
rca_label_clone() {
    # Self-registration: handle label clone commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "label clone" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough - supports all native parameters
    exec gh label clone "$@"
}

#
# EXTENSION SYSTEM COMMANDS (for future PM system integration)
#

# gh extension list - List installed extensions
# Usage: repocli extension list
# Returns: List of installed extensions
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:init (extension detection)
# PM patterns: if repocli extension list | grep -q "yahsan2/gh-sub-issue"; then
# Expected output: List of extensions that can be grepped for specific names
# Error detection: stdout catching "yahsan2/gh-sub-issue"
# CRITICAL: Output format must be greppable for extension detection
rca_extension_list() {
    # GitHub: Direct passthrough - supports all native parameters
    exec gh extension list "$@"
}

# gh extension install - Install GitHub CLI extension
# Usage: repocli extension install EXTENSION_NAME
# Parameters:
#   EXTENSION_NAME: Name or URL of extension to install
# Returns: Success status
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:init (gh-sub-issue extension installation)
# PM patterns: gh extension install yahsan2/gh-sub-issue
# Expected output: Installation success/failure with proper exit codes
# Error detection: not yet analyzed
# CRITICAL: Must handle extension installation and return proper status
rca_extension_install() {
    # GitHub: Direct passthrough - supports all native parameters
    exec gh extension install "$@"
}

#
# VERSION AND UTILITY COMMANDS (for PM system compatibility)
#

# gh --version - Display GitHub CLI version
# Usage: repocli --version
# Returns: Version information
#
# PM SYSTEM USAGE:
# Used by PM commands: /pm:init (version display), /pm:status (status summary)
# PM patterns: gh --version | head -1
# Expected output: Must support version display with proper first line formatting
# Error detection: not yet analyzed
# CRITICAL: Version output must be consistent for PM status reporting
rca_version() {
    # Self-registration: handle version commands
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1" == "--version" ]] && return 0 || return 1
    fi
    
    # GitHub: Direct passthrough to gh --version
    exec gh --version "$@"
}