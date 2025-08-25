#!/bin/bash
# Shared test utilities for cross-testing framework

# Source isolation utilities
source "$(dirname "${BASH_SOURCE[0]}")/test-isolation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/provider-config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Debug logging
debug_log() {
    if [[ "${REPOCLI_DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Warning logging
warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Configuration helpers (enhanced with isolation support)
create_test_config() {
    local provider="$1"
    local instance="${2:-}"
    local config_file="$3"
    
    debug_log "Creating test config: $provider -> $config_file"
    
    # Use the new provider config generation if available
    if command -v generate_provider_config >/dev/null 2>&1; then
        generate_provider_config "$provider" "$instance" "" "" > "$config_file"
    else
        # Fallback to simple generation
        cat > "$config_file" << EOF
provider=$provider
EOF
        
        if [[ -n "$instance" ]]; then
            echo "instance=$instance" >> "$config_file"
        fi
    fi
}

# Cleanup helpers
cleanup_test_files() {
    local pattern="$1"
    find . -name "$pattern" -delete 2>/dev/null || true
}

# Test environment isolation (DEPRECATED - use isolation library functions instead)
setup_test_environment() {
    local test_name="$1"
    local test_dir="$2"
    
    warning "setup_test_environment is deprecated, use init_test_isolation instead"
    
    # Create isolated working directory
    local work_dir="$test_dir/work"
    mkdir -p "$work_dir"
    
    # Backup original config if it exists
    if [[ -f "$REPOCLI_DIR/repocli.conf" ]]; then
        cp "$REPOCLI_DIR/repocli.conf" "$work_dir/repocli.conf.backup"
    fi
    
    echo "$work_dir"
}

# Clean up test environment (DEPRECATED - use cleanup_test_isolation instead)
cleanup_test_environment() {
    local work_dir="$1"
    
    warning "cleanup_test_environment is deprecated, use cleanup_test_isolation instead"
    
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

# Enhanced test environment setup using isolation system
setup_isolated_test() {
    local test_name="$1"
    local provider="$2"
    local custom_instance="${3:-}"
    local additional_config="${4:-}"
    
    debug_log "Setting up isolated test: $test_name ($provider)"
    
    # Initialize and activate isolation
    if ! init_test_isolation "$test_name" "$provider" "$custom_instance"; then
        echo "Error: Failed to initialize test isolation"
        return 1
    fi
    
    if ! create_isolated_config "$provider" "$custom_instance" "$additional_config"; then
        echo "Error: Failed to create isolated configuration"
        cleanup_test_isolation
        return 1
    fi
    
    if ! activate_test_isolation; then
        echo "Error: Failed to activate test isolation"
        cleanup_test_isolation
        return 1
    fi
    
    debug_log "Isolated test environment ready"
    return 0
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
    local instance="${2:-}"
    
    # Use provider config library if available
    if command -v get_provider_test_repository >/dev/null 2>&1; then
        get_provider_test_repository "$provider" "$instance"
    else
        # Fallback to simple mapping
        case "$provider" in
            "github") echo "microsoft/vscode" ;;
            "gitlab") echo "gitlab-org/gitlab" ;;
            "gitea") echo "gitea/tea" ;;
            "codeberg") echo "forgejo/forgejo" ;;
            *) echo "" ;;
        esac
    fi
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