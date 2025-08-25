#!/bin/bash
# GitLab Provider for REPOCLI
# Maps GitHub CLI (gh) commands to GitLab CLI (glab) equivalents

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
    
    case "$cmd" in
        # Authentication commands
        "auth")
            case "$1" in
                "status")
                    exec glab auth status
                    ;;
                "login")
                    exec glab auth login
                    ;;
                *)
                    exec glab auth "$@"
                    ;;
            esac
            ;;
            
        # Issue operations
        "issue")
            gitlab_issue_command "$@"
            ;;
            
        # Repository operations
        "repo")
            gitlab_repo_command "$@"
            ;;
            
        # Sub-issue operations (not supported)
        "sub-issue")
            echo "Error: sub-issue operations not directly supported in GitLab" >&2
            echo "Use 'repocli issue create' with issue relationships instead" >&2
            exit 1
            ;;
            
        # Extension operations (not needed)
        "extension")
            case "$1" in
                "list")
                    echo "GitLab CLI doesn't use extensions" >&2
                    ;;
                "install")
                    echo "Extensions not needed for GitLab CLI" >&2
                    ;;
                *)
                    echo "Extension command not supported for GitLab" >&2
                    ;;
            esac
            ;;
            
        # Version command
        "--version")
            exec glab version
            ;;
            
        *)
            # Pass through unknown commands to glab
            debug_log "Passing through unknown command to glab: $cmd $*"
            exec glab "$cmd" "$@"
            ;;
    esac
}

# Handle issue commands
gitlab_issue_command() {
    local subcmd="$1"
    shift
    
    case "$subcmd" in
        "view")
            gitlab_issue_view "$@"
            ;;
        "create")
            gitlab_issue_create "$@"
            ;;
        "edit")
            gitlab_issue_edit "$@"
            ;;
        "comment")
            gitlab_issue_comment "$@"
            ;;
        "close")
            gitlab_issue_close "$@"
            ;;
        "reopen")
            local issue_num="$1"
            exec glab issue reopen "$issue_num"
            ;;
        "list")
            gitlab_issue_list "$@"
            ;;
        *)
            echo "Error: Unsupported issue command '$subcmd' for GitLab" >&2
            echo "Supported commands: view, create, edit, comment, close, reopen, list" >&2
            exit 1
            ;;
    esac
}

# Handle repo commands
gitlab_repo_command() {
    case "$1" in
        "view")
            shift
            if [[ "$*" == *"--json nameWithOwner"* ]]; then
                # Get repository identifier
                glab repo view --output json | jq -r '.path_with_namespace'
            else
                exec glab repo view "$@"
            fi
            ;;
        *)
            echo "Error: Unsupported repo command '$1' for GitLab" >&2
            echo "Supported commands: view" >&2
            exit 1
            ;;
    esac
}

# GitLab issue view with gh compatibility
gitlab_issue_view() {
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

# GitLab issue create with gh compatibility
gitlab_issue_create() {
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

# GitLab issue edit with gh compatibility
gitlab_issue_edit() {
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

# GitLab issue comment with gh compatibility
gitlab_issue_comment() {
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

# GitLab issue close with gh compatibility
gitlab_issue_close() {
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

# GitLab issue list with gh compatibility
gitlab_issue_list() {
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