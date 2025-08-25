#!/bin/bash
# Shared test utilities for cross-testing framework

# Debug logging
debug_log() {
    if [[ "${REPOCLI_DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Configuration helpers
create_test_config() {
    local provider="$1"
    local instance="${2:-}"
    local config_file="$3"
    
    cat > "$config_file" << EOF
provider=$provider
EOF
    
    if [[ -n "$instance" ]]; then
        echo "instance=$instance" >> "$config_file"
    fi
}

# Cleanup helpers
cleanup_test_files() {
    local pattern="$1"
    find . -name "$pattern" -delete 2>/dev/null || true
}

# Test environment isolation
setup_test_environment() {
    local test_name="$1"
    local test_dir="$2"
    
    # Create isolated working directory
    local work_dir="$test_dir/work"
    mkdir -p "$work_dir"
    
    # Backup original config if it exists
    if [[ -f "$REPOCLI_DIR/repocli.conf" ]]; then
        cp "$REPOCLI_DIR/repocli.conf" "$work_dir/repocli.conf.backup"
    fi
    
    echo "$work_dir"
}

# Clean up test environment
cleanup_test_environment() {
    local work_dir="$1"
    
    # Restore original config if backed up
    if [[ -f "$work_dir/repocli.conf.backup" ]]; then
        mv "$work_dir/repocli.conf.backup" "$REPOCLI_DIR/repocli.conf"
    else
        # Remove test config
        rm -f "$REPOCLI_DIR/repocli.conf"
    fi
    
    # Clean up work directory
    rm -rf "$work_dir"
}

# JSON comparison helpers
normalize_json() {
    local json_file="$1"
    # Normalize JSON formatting for comparison
    jq -S . "$json_file" 2>/dev/null || cat "$json_file"
}

# Test repository constants (public repos for read-only testing)
get_test_repo() {
    local provider="$1"
    case "$provider" in
        "github") echo "microsoft/vscode" ;;
        "gitlab") echo "gitlab-org/gitlab" ;;
        *) echo "" ;;
    esac
}

# Validate JSON structure
validate_json_structure() {
    local json_file="$1"
    local required_fields="$2"  # Space-separated list of required fields
    
    if ! jq -e . "$json_file" >/dev/null 2>&1; then
        echo "Invalid JSON format"
        return 1
    fi
    
    for field in $required_fields; do
        if ! jq -e ".$field" "$json_file" >/dev/null 2>&1; then
            echo "Missing required field: $field"
            return 1
        fi
    done
    
    return 0
}

# Test timing
start_timer() {
    echo $SECONDS
}

end_timer() {
    local start_time="$1"
    echo $((SECONDS - start_time))
}