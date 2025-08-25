#!/bin/bash
# GitLab Provider for REPOCLI
# Maps GitHub CLI (gh) commands to GitLab CLI (glab) equivalents
# Implements the standardized rca_ functions defined in GitHub provider

# Execute GitLab commands with GitHub CLI compatibility
gitlab_execute() {
    debug_log "GitLab provider executing with gh compatibility: $*"
    
    # Check if glab CLI is available
    if ! check_cli_tool "glab"; then
        exit 1
    fi
    
    # Set hostname for custom GitLab instances
    if [[ -n "$REPOCLI_INSTANCE" ]] && [[ "$REPOCLI_INSTANCE" != "https://gitlab.com" ]]; then
        # Extract hostname from URL
        local hostname=$(echo "$REPOCLI_INSTANCE" | sed 's|^https\?://||' | sed 's|/.*$||')
        export GITLAB_HOST="$hostname"
        debug_log "Using GitLab instance: $hostname"
    fi
    
    local cmd="$1"
    shift
    
    # Query each rca_ function to see if it can handle this command
    # First function that says "yes" wins (automatic discovery)
    for func in $(declare -F | grep -o 'rca_[a-zA-Z_]*' | sort); do
        if "$func" --repocli-can-handle "$cmd" "$@" 2>/dev/null; then
            debug_log "GitLab: Routing to $func for command: $cmd $*"
            "$func" "$cmd" "$@"
            return
        fi
    done
    
    # 🚨 RED FLAG: Command not handled by any rca_ function
    echo "🚨 REPOCLI ERROR: Command '$cmd $*' not supported by GitLab provider" >&2
    echo "   Available commands must be implemented as rca_ functions" >&2
    echo "   This indicates missing functionality that needs to be implemented" >&2
    debug_log "RED FLAG: Unsupported command attempted: $cmd $*"
    exit 1
}

# Authentication commands with standardized rca_ naming
# Implements GitHub CLI rca_auth_status() for GitLab
rca_auth_status() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "auth status" ]] && return 0 || return 1
    fi
    
    debug_log "GitLab: Checking authentication status"
    exec glab auth status
}

# Implements GitHub CLI rca_auth_login() for GitLab
rca_auth_login() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ $# -ge 2 && "$1 $2" == "auth login" ]] && return 0 || return 1
    fi
    
    debug_log "GitLab: Starting authentication login"
    exec glab auth login "$@"
}

# Repository operations with standardized rca_ naming
# Implements GitHub CLI rca_repo_view() for GitLab
rca_repo_view() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "repo view" ]] && return 0 || return 1
    fi
    
    debug_log "GitLab: Viewing repository"
    
    if [[ "$*" == *"--json nameWithOwner"* ]]; then
        # Get repository identifier - map GitHub field to GitLab equivalent
        glab repo view --output json | jq -r '.path_with_namespace'
    else
        exec glab repo view "$@"
    fi
}

# Issue management commands with standardized rca_ naming
# Implements GitHub CLI rca_issue_view() for GitLab
rca_issue_view() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue view" ]] && return 0 || return 1
    fi
    
    local issue_num="$1"
    shift
    
    local json_fields=""
    local query=""
    local comments=false
    local web=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--json")
                json_fields="$2"
                shift 2
                ;;
            "-q"|"--jq")
                query="$2"
                shift 2
                ;;
            "--comments")
                comments=true
                shift
                ;;
            "--web")
                web=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ "$web" == "true" ]]; then
        exec glab issue view "$issue_num" --web
    elif [[ -n "$json_fields" ]]; then
        # Map JSON fields from gh to glab format
        case "$json_fields" in
            "state,title,labels,body"|"state,title,labels,assignees,updatedAt")
                glab issue view "$issue_num" --output json | jq -r "$query"
                ;;
            "body")
                glab issue view "$issue_num" --output json | jq -r '.description'
                ;;
            "number")
                echo "$issue_num"
                ;;
            *)
                glab issue view "$issue_num" --output json | jq -r "$query"
                ;;
        esac
    elif [[ "$comments" == "true" ]]; then
        glab issue view "$issue_num" && glab issue note list "$issue_num"
    else
        exec glab issue view "$issue_num"
    fi
}

rca_issue_create() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue create" ]] && return 0 || return 1
    fi
    
    local title=""
    local body_file=""
    local labels=""
    local assignee=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--title")
                title="$2"
                shift 2
                ;;
            "--body-file")
                body_file="$2"
                shift 2
                ;;
            "--label")
                labels="$2"
                shift 2
                ;;
            "--assignee")
                assignee="$2"
                shift 2
                ;;
            "--json"|"-q"|"--jq")
                # Skip JSON output options for create
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    local glab_cmd="glab issue create"
    
    if [[ -n "$title" ]]; then
        glab_cmd="$glab_cmd --title \"$title\""
    fi
    
    if [[ -n "$body_file" ]]; then
        if [[ "$body_file" == "-" ]]; then
            glab_cmd="$glab_cmd --description-file /dev/stdin"
        else
            glab_cmd="$glab_cmd --description-file \"$body_file\""
        fi
    fi
    
    if [[ -n "$labels" ]]; then
        # Convert comma-separated labels to GitLab format
        local converted_labels=$(echo "$labels" | sed 's/,/ --label /g')
        glab_cmd="$glab_cmd --label $converted_labels"
    fi
    
    if [[ -n "$assignee" ]]; then
        if [[ "$assignee" == "@me" ]]; then
            glab_cmd="$glab_cmd --assignee @me"
        else
            glab_cmd="$glab_cmd --assignee \"$assignee\""
        fi
    fi
    
    # Execute and capture issue number
    eval "$glab_cmd" | grep -o 'https://[^/]*/[^/]*/[^/]*/-/issues/[0-9]*' | sed 's|.*/||'
}

rca_issue_edit() {
    local issue_num="$1"
    shift
    
    local glab_cmd="glab issue edit $issue_num"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--add-label")
                glab_cmd="$glab_cmd --add-label \"$2\""
                shift 2
                ;;
            "--remove-label")
                glab_cmd="$glab_cmd --remove-label \"$2\""
                shift 2
                ;;
            "--add-assignee")
                if [[ "$2" == "@me" ]]; then
                    glab_cmd="$glab_cmd --assignee @me"
                else
                    glab_cmd="$glab_cmd --assignee \"$2\""
                fi
                shift 2
                ;;
            "--title")
                glab_cmd="$glab_cmd --title \"$2\""
                shift 2
                ;;
            "--body-file")
                if [[ "$2" == "-" ]]; then
                    glab_cmd="$glab_cmd --description-file /dev/stdin"
                else
                    glab_cmd="$glab_cmd --description-file \"$2\""
                fi
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    eval "$glab_cmd"
}

rca_issue_comment() {
    local issue_num="$1"
    shift
    
    local body_file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--body-file")
                body_file="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -n "$body_file" ]]; then
        if [[ "$body_file" == "-" ]]; then
            glab issue note create "$issue_num" --message "$(cat)"
        else
            glab issue note create "$issue_num" --message "$(cat "$body_file")"
        fi
    fi
}

rca_issue_close() {
    local issue_num="$1"
    shift
    
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--comment"|"-c")
                comment="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -n "$comment" ]]; then
        glab issue note create "$issue_num" --message "$comment"
    fi
    glab issue close "$issue_num"
}

rca_issue_reopen() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue reopen" ]] && return 0 || return 1
    fi
    
    local issue_num="$1"
    debug_log "GitLab: Reopening issue $issue_num"
    exec glab issue reopen "$issue_num"
}

rca_issue_list() {
    # Self-registration: handle --repocli-can-handle query
    if [[ "$1" == "--repocli-can-handle" ]]; then
        shift
        [[ "$1 $2" == "issue list" ]] && return 0 || return 1
    fi
    
    local labels=""
    local limit=""
    local json_fields=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--label")
                labels="$2"
                shift 2
                ;;
            "--limit")
                limit="$2"
                shift 2
                ;;
            "--json")
                json_fields="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    local glab_cmd="glab issue list --output json"
    
    if [[ -n "$labels" ]]; then
        glab_cmd="$glab_cmd --label=\"$labels\""
    fi
    
    if [[ -n "$limit" ]]; then
        glab_cmd="$glab_cmd | head -n $limit"
    fi
    
    eval "$glab_cmd"
}

# Label management commands with standardized rca_ naming
# Extension system commands (not applicable for GitLab)
rca_extension_list() {
    [[ "$1" == "--repocli-can-handle" ]] && { echo "extension list"; return 0; }
    
    debug_log "GitLab: Extensions not applicable"
    echo "GitLab CLI doesn't use extensions" >&2
}

rca_extension_install() {
    [[ "$1" == "--repocli-can-handle" ]] && { echo "extension install"; return 0; }
    
    debug_log "GitLab: Extensions not applicable"
    echo "Extensions not needed for GitLab CLI" >&2
}

rca_label_create() {
    local name=""
    local description=""
    local color=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "-c"|"--color")
                color="$2"
                shift 2
                ;;
            "-d"|"--description")
                description="$2"
                shift 2
                ;;
            "-f"|"--force")
                force=true
                shift
                ;;
            -*)
                shift
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        echo "Error: label name is required" >&2
        exit 1
    fi
    
    local glab_cmd="glab label create --name \"$name\""
    
    if [[ -n "$description" ]]; then
        glab_cmd="$glab_cmd --description \"$description\""
    fi
    
    if [[ -n "$color" ]]; then
        # Remove # if present for GitLab
        color=${color#\#}
        glab_cmd="$glab_cmd --color \"#$color\""
    fi
    
    # GitLab doesn't have --force, but we can check if label exists and update
    if [[ "$force" == "true" ]]; then
        if glab label list --output json | jq -e ".[] | select(.name == \"$name\")" > /dev/null 2>&1; then
            # Label exists, use edit instead
            rca_label_edit "$name" ${description:+--description "$description"} ${color:+--color "$color"}
            return
        fi
    fi
    
    eval "$glab_cmd"
}

rca_label_list() {
    local json_fields=""
    local query=""
    local limit=""
    local search=""
    local web=false
    local sort=""
    local order=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--json")
                json_fields="$2"
                shift 2
                ;;
            "-q"|"--jq")
                query="$2"
                shift 2
                ;;
            "-L"|"--limit")
                limit="$2"
                shift 2
                ;;
            "-S"|"--search")
                search="$2"
                shift 2
                ;;
            "-w"|"--web")
                web=true
                shift
                ;;
            "--sort")
                sort="$2"
                shift 2
                ;;
            "--order")
                order="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ "$web" == "true" ]]; then
        # GitLab doesn't support web view for labels, show error
        echo "Error: --web not supported for GitLab labels" >&2
        exit 1
    fi
    
    local glab_cmd="glab label list"
    
    if [[ -n "$json_fields" ]] || [[ -n "$query" ]]; then
        glab_cmd="$glab_cmd --output json"
    fi
    
    if [[ -n "$limit" ]]; then
        glab_cmd="$glab_cmd --per-page $limit"
    fi
    
    # Execute command and apply jq filter if needed
    if [[ -n "$query" ]]; then
        eval "$glab_cmd" | jq -r "$query"
    else
        eval "$glab_cmd"
    fi
}

rca_label_edit() {
    local label_name="$1"
    shift
    
    if [[ -z "$label_name" ]]; then
        echo "Error: label name is required" >&2
        exit 1
    fi
    
    local new_name=""
    local description=""
    local color=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "-n"|"--name")
                new_name="$2"
                shift 2
                ;;
            "-c"|"--color")
                color="$2"
                shift 2
                ;;
            "-d"|"--description")
                description="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # GitLab doesn't have a direct edit command, need to delete and recreate
    # First get current label info
    local current_label=$(glab label list --output json | jq -r ".[] | select(.name == \"$label_name\")")
    
    if [[ -z "$current_label" ]]; then
        echo "Error: label '$label_name' not found" >&2
        exit 1
    fi
    
    # Extract current values if not provided
    if [[ -z "$new_name" ]]; then
        new_name="$label_name"
    fi
    
    if [[ -z "$description" ]]; then
        description=$(echo "$current_label" | jq -r '.description // ""')
    fi
    
    if [[ -z "$color" ]]; then
        color=$(echo "$current_label" | jq -r '.color // ""')
    fi
    
    # Delete old label and create new one
    glab label delete "$label_name"
    rca_label_create "$new_name" ${description:+--description "$description"} ${color:+--color "$color"}
}

rca_label_delete() {
    local label_name="$1"
    local yes=false
    
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--yes")
                yes=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -z "$label_name" ]]; then
        echo "Error: label name is required" >&2
        exit 1
    fi
    
    # GitLab CLI doesn't prompt by default, so --yes doesn't change behavior
    exec glab label delete "$label_name"
}

rca_label_clone() {
    [[ "$1" == "--repocli-can-handle" ]] && { echo "label clone"; return 0; }
    
    debug_log "GitLab: Label clone not supported"
    echo "Error: 'label clone' not supported in GitLab" >&2
    echo "Use 'repocli label list --json' and 'repocli label create' instead" >&2
    exit 1
}

# Version command
rca_version() {
    [[ "$1" == "--repocli-can-handle" ]] && { echo "--version"; return 0; }
    
    debug_log "GitLab: Handling version command"
    exec glab version
}