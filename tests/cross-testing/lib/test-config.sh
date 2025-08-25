#!/bin/bash
# Test Configuration Utilities for Cross-Provider Testing
# Uses temporary config files injected via REPOCLI_CONFIG environment variable
#
# USAGE EXAMPLES:
#
# # Validate test environment before running tests
# validate_test_configuration
#
# # Single provider tests
# run_test_with_provider "github" my_test_function
# run_test_with_provider "gitlab" my_test_function  
#
# # Cross-provider comparison
# run_cross_provider_test my_test_function
#
# # Manual setup/cleanup
# setup_test_with_provider "github"
# # ... run tests with REPOCLI_CONFIG set ...
# cleanup_test_config
#
# KEY PRINCIPLE: Uses only REPOCLI_CONFIG environment variable for configuration 
# injection - no artificial multiplication of environment variables.

# Source existing utilities
source "$(dirname "${BASH_SOURCE[0]}")/test-isolation.sh" 2>/dev/null || true

# Debug logging (compatible with existing framework)
debug_log() {
    if [[ "${REPOCLI_DEBUG:-}" == "1" ]]; then
        echo -e "\033[0;34m[DEBUG]\033[0m $1" >&2
    fi
}

# Create temporary repocli.conf for specified provider
# Args: provider
# Returns: path to temporary config file
create_temp_config() {
    local provider="$1"
    local temp_config
    temp_config=$(mktemp /tmp/repocli-test-XXXXXX.conf)
    
    debug_log "🔧 Creating temporary config for provider: $provider"
    debug_log "📄 Temporary config file: $temp_config"
    
    case "$provider" in
        "github")
            echo "provider=github" > "$temp_config"
            debug_log "✅ GitHub provider config created"
            ;;
        "gitlab")
            # Load .tests.conf if it exists for GitLab repository settings
            if [[ -f .tests.conf ]]; then
                source .tests.conf
                debug_log "📋 Loaded GitLab settings from .tests.conf"
                debug_log "   - Instance: ${gitlab_test_instance:-<not set>}"
                debug_log "   - Repository: ${gitlab_test_repo:-<not set>}"
            else
                debug_log "⚠️  No .tests.conf found, using defaults"
            fi
            echo "provider=gitlab" > "$temp_config"
            local instance="${gitlab_test_instance:-https://gitlab.com}"
            echo "instance=$instance" >> "$temp_config"
            debug_log "✅ GitLab provider config created with instance: $instance"
            ;;
        *)
            debug_log "❌ Unknown provider: $provider"
            echo "Error: Unknown provider '$provider'" >&2
            rm -f "$temp_config"
            return 1
            ;;
    esac
    
    echo "$temp_config"
}

# Set up test with provider-specific configuration via REPOCLI_CONFIG only
# Args: provider
setup_test_with_provider() {
    local provider="$1"
    local temp_config
    temp_config=$(create_temp_config "$provider")
    
    if [[ -z "$temp_config" ]]; then
        echo "Error: Failed to create temporary config for provider: $provider" >&2
        return 1
    fi
    
    export REPOCLI_CONFIG="$temp_config"
    debug_log "🎯 REPOCLI_CONFIG set to: $REPOCLI_CONFIG"
    debug_log "📋 Provider: $provider"
    
    return 0
}

# Clean up temporary configuration - minimal approach
cleanup_test_config() {
    debug_log "Cleaning up test configuration"
    
    if [[ -n "${REPOCLI_CONFIG:-}" && -f "$REPOCLI_CONFIG" ]]; then
        rm -f "$REPOCLI_CONFIG"
        debug_log "Removed temporary config: $REPOCLI_CONFIG"
    fi
    unset REPOCLI_CONFIG
    
    debug_log "Test configuration cleanup completed"
}

# Validate test configuration and CLI tool availability
validate_test_configuration() {
    echo "🔍 Validating test configuration..."
    
    # Debug: Show configuration file lookup process
    debug_log "🔍 Configuration file lookup process:"
    debug_log "  - REPOCLI_CONFIG: ${REPOCLI_CONFIG:-<not set>}"
    debug_log "  - ./repocli.conf: $([ -f ./repocli.conf ] && echo "exists" || echo "not found")"
    debug_log "  - ~/.repocli.conf: $([ -f ~/.repocli.conf ] && echo "exists" || echo "not found")"
    debug_log "  - ~/.config/repocli/config: $([ -f ~/.config/repocli/config ] && echo "exists" || echo "not found")"
    
    # Show active configuration source
    if [[ -n "${REPOCLI_CONFIG:-}" ]]; then
        debug_log "🎯 Active config: $REPOCLI_CONFIG (temporary test config)"
    elif [[ -f ./repocli.conf ]]; then
        debug_log "🎯 Active config: ./repocli.conf (project-specific)"
    elif [[ -f ~/.repocli.conf ]]; then
        debug_log "🎯 Active config: ~/.repocli.conf (user-specific)"
    elif [[ -f ~/.config/repocli/config ]]; then
        debug_log "🎯 Active config: ~/.config/repocli/config (XDG compliant)"
    else
        debug_log "🎯 Active config: none found"
    fi
    
    # Check GitHub CLI availability
    if command -v gh >/dev/null 2>&1; then
        echo "✅ GitHub CLI available"
    else
        echo "⚠️ GitHub CLI not available - GitHub tests will be skipped"
    fi
    
    # Check GitLab CLI availability  
    if command -v glab >/dev/null 2>&1; then
        echo "✅ GitLab CLI available"
        
        # Check .tests.conf for GitLab repository settings
        if [[ -f .tests.conf ]]; then
            echo "✅ GitLab test configuration found"
            debug_log "📋 .tests.conf found for GitLab testing"
            
            # Validate .tests.conf content
            if grep -q "gitlab_test_repo=" .tests.conf 2>/dev/null; then
                echo "✅ GitLab test repository configured"
            else
                echo "⚠️ GitLab test repository not configured in .tests.conf"
            fi
        else
            echo "⚠️ No .tests.conf - run /tests:init for GitLab testing"
            debug_log "📋 .tests.conf not found"
        fi
    else
        echo "⚠️ GitLab CLI not available - GitLab tests will be skipped"
    fi
    
    return 0
}

# Cross-provider test execution with REPOCLI_CONFIG injection
# Args: test_function
run_cross_provider_test() {
    local test_function="$1"
    
    if [[ -z "$test_function" ]]; then
        echo "Error: No test function specified" >&2
        return 1
    fi
    
    if ! command -v "$test_function" >/dev/null 2>&1; then
        echo "Error: Test function '$test_function' not found" >&2
        return 1
    fi
    
    echo "🔄 Cross-provider test: $test_function"
    
    # Test with GitHub provider (baseline)
    echo "📋 GitHub provider test..."
    local github_result github_exit
    if setup_test_with_provider "github"; then
        github_result=$($test_function 2>&1)
        github_exit=$?
        cleanup_test_config
    else
        echo "❌ Failed to set up GitHub provider test"
        github_exit=1
        github_result="Setup failed"
    fi
    
    # Test with GitLab provider (translation)
    echo "📋 GitLab provider test..."
    local gitlab_result gitlab_exit
    if setup_test_with_provider "gitlab"; then
        gitlab_result=$($test_function 2>&1)
        gitlab_exit=$?
        cleanup_test_config
    else
        echo "❌ Failed to set up GitLab provider test"
        gitlab_exit=1
        gitlab_result="Setup failed"
    fi
    
    # Compare results
    echo "GitHub exit: $github_exit, GitLab exit: $gitlab_exit"
    if [[ $github_exit -eq $gitlab_exit ]]; then
        echo "✅ Exit codes match"
        return 0
    else
        echo "❌ Exit codes differ"
        echo "GitHub result: $github_result"
        echo "GitLab result: $gitlab_result"
        return 1
    fi
}

# Simple single-provider test execution
# Args: provider test_function
run_test_with_provider() {
    local provider="$1"
    local test_function="$2"
    
    if [[ -z "$provider" || -z "$test_function" ]]; then
        echo "Error: Provider and test function must be specified" >&2
        return 1
    fi
    
    if ! command -v "$test_function" >/dev/null 2>&1; then
        echo "Error: Test function '$test_function' not found" >&2
        return 1
    fi
    
    debug_log "Running test with provider: $provider, function: $test_function"
    
    if ! setup_test_with_provider "$provider"; then
        echo "Error: Failed to set up test with provider: $provider" >&2
        return 1
    fi
    
    # Execute the test function
    local exit_code=0
    "$test_function" || exit_code=$?
    
    # Always cleanup
    cleanup_test_config
    
    return $exit_code
}

# Enhanced validation with provider-specific checks
# Args: provider
validate_provider_setup() {
    local provider="$1"
    
    case "$provider" in
        "github")
            if ! command -v gh >/dev/null 2>&1; then
                echo "Error: GitHub CLI (gh) not available" >&2
                return 1
            fi
            
            # Check authentication
            if ! gh auth status >/dev/null 2>&1; then
                echo "Warning: GitHub CLI not authenticated" >&2
            fi
            ;;
        "gitlab")
            if ! command -v glab >/dev/null 2>&1; then
                echo "Error: GitLab CLI (glab) not available" >&2
                return 1
            fi
            
            # Check for test configuration
            if [[ ! -f .tests.conf ]]; then
                echo "Error: .tests.conf not found - run /tests:init for GitLab testing" >&2
                return 1
            fi
            
            # Check authentication
            if ! glab auth status >/dev/null 2>&1; then
                echo "Warning: GitLab CLI not authenticated" >&2
            fi
            ;;
        *)
            echo "Error: Unknown provider '$provider'" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Test configuration info display
show_test_config_info() {
    echo "📋 Test Configuration Information"
    echo "================================="
    
    if [[ -n "${REPOCLI_CONFIG:-}" ]]; then
        echo "Active config file: $REPOCLI_CONFIG"
        if [[ -f "$REPOCLI_CONFIG" ]]; then
            echo "Config content:"
            sed 's/^/  /' "$REPOCLI_CONFIG"
        else
            echo "⚠️ Config file not found"
        fi
    else
        echo "No active test configuration"
    fi
    
    echo ""
    validate_test_configuration
}

# Cleanup function for use in traps
cleanup_on_exit() {
    cleanup_test_config
}

# Set up cleanup trap for script usage
trap cleanup_on_exit EXIT INT TERM