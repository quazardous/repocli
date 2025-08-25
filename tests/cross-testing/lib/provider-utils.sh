#!/bin/bash
# Provider-specific utility functions

# Source shared utilities and isolation libraries
source "$(dirname "${BASH_SOURCE[0]}")/test-isolation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/provider-config.sh"

# Provider configuration mapping (maintained for backward compatibility)
get_provider_cli_tool() {
    local provider="$1"
    
    # Use new provider config system if available
    if command -v init_provider_configs >/dev/null 2>&1; then
        init_provider_configs 2>/dev/null || true
        if [[ -n "${PROVIDER_CLI_TOOLS[$provider]:-}" ]]; then
            echo "${PROVIDER_CLI_TOOLS[$provider]}"
            return 0
        fi
    fi
    
    # Fallback to hardcoded mapping
    case "$provider" in
        "github") echo "gh" ;;
        "gitlab") echo "glab" ;;
        "gitea"|"codeberg") echo "tea" ;;
        *) return 1 ;;
    esac
}

# Authentication status checking
check_provider_auth() {
    local provider="$1"
    local cli_tool
    cli_tool=$(get_provider_cli_tool "$provider")
    
    if command -v "$cli_tool" &>/dev/null; then
        "$cli_tool" auth status &>/dev/null
    else
        return 1
    fi
}

# Execute REPOCLI command with provider context (enhanced with isolation support)
execute_repocli_test() {
    local provider="$1"
    local test_dir="$2"
    shift 2
    local command=("$@")
    
    debug_log "Executing REPOCLI test: $provider ${command[*]}"
    
    # Check if isolation is active
    if [[ "$ISOLATION_ACTIVE" == "true" ]]; then
        # Use isolation system
        debug_log "Using isolation system for test execution"
        execute_isolated cd "$REPOCLI_DIR" && "$REPOCLI_BIN" "${command[@]}"
    else
        # Fallback to old behavior
        debug_log "Using fallback execution method"
        
        # Set up provider configuration
        local config_file="$test_dir/repocli.conf"
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$REPOCLI_DIR/repocli.conf"
        fi
        
        # Execute command from REPOCLI directory
        cd "$REPOCLI_DIR"
        "$REPOCLI_BIN" "${command[@]}"
    fi
}

# Execute REPOCLI command in isolated environment
execute_repocli_isolated() {
    local command=("$@")
    
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        echo "Error: Isolation not active for isolated execution"
        return 1
    fi
    
    debug_log "Executing isolated REPOCLI command: ${command[*]}"
    
    # Change to REPOCLI directory and execute
    cd "$REPOCLI_DIR" || return 1
    "$REPOCLI_BIN" "${command[@]}"
}

# Compare command outputs between providers
compare_provider_outputs() {
    local github_output="$1"
    local provider_output="$2"
    local comparison_type="${3:-json}"
    
    case "$comparison_type" in
        "json")
            # Use jq for semantic JSON comparison
            local github_normalized provider_normalized
            github_normalized=$(jq -S . "$github_output" 2>/dev/null || echo "{}")
            provider_normalized=$(jq -S . "$provider_output" 2>/dev/null || echo "{}")
            
            if [[ "$github_normalized" == "$provider_normalized" ]]; then
                return 0
            else
                echo "JSON outputs differ"
                echo "GitHub output: $github_normalized"
                echo "Provider output: $provider_normalized"
                return 1
            fi
            ;;
        "text")
            # Simple text comparison
            if diff -q "$github_output" "$provider_output" >/dev/null; then
                return 0
            else
                echo "Text outputs differ"
                echo "Differences:"
                diff "$github_output" "$provider_output" || true
                return 1
            fi
            ;;
        *)
            echo "Unknown comparison type: $comparison_type"
            return 1
            ;;
    esac
}

# Extract specific fields from JSON for comparison
extract_json_fields() {
    local json_file="$1"
    local fields="$2"  # Comma-separated jq field expressions
    
    jq -r "$fields" "$json_file" 2>/dev/null || echo ""
}

# Generate test report
generate_test_report() {
    local provider="$1"
    local test_name="$2"
    local result="$3"
    local details="$4"
    local output_file="$5"
    
    cat >> "$output_file" << EOF
## Test: $test_name
**Provider**: $provider
**Result**: $result
**Details**: $details
**Timestamp**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

---

EOF
}

# Provider-specific test repositories and endpoints
get_provider_test_config() {
    local provider="$1"
    
    case "$provider" in
        "github")
            echo "repo=microsoft/vscode"
            echo "api_host=github.com"
            ;;
        "gitlab")
            echo "repo=gitlab-org/gitlab"
            echo "api_host=gitlab.com"
            ;;
        "gitlab-custom")
            local instance="${GITLAB_TEST_INSTANCE:-gitlab.example.com}"
            echo "repo=group/project"
            echo "api_host=$instance"
            ;;
        *)
            echo "# Unknown provider: $provider"
            ;;
    esac
}

# Validate provider configuration
validate_provider_config() {
    local config_file="$1"
    local provider
    provider=$(grep "^provider=" "$config_file" | cut -d'=' -f2)
    
    case "$provider" in
        "github"|"gitlab"|"gitea"|"codeberg")
            return 0
            ;;
        *)
            echo "Invalid provider: $provider"
            return 1
            ;;
    esac
}