#!/bin/bash
# Test Environment Isolation Utilities
# Provides comprehensive environment isolation for cross-testing framework

# Global isolation state tracking
declare -A ISOLATION_STATE
ISOLATION_TEMP_DIR=""
ISOLATION_BACKUP_DIR=""
ISOLATION_ACTIVE=false

# Configuration file locations for backup (in order of preference)
ISOLATION_CONFIG_LOCATIONS=(
    "./repocli.conf"
    "$HOME/.repocli.conf"
    "$HOME/.config/repocli/config"
)

# Initialize test isolation environment
# Creates temporary directories and prepares for configuration isolation
# Args: test_name test_provider [custom_instance]
init_test_isolation() {
    local test_name="$1"
    local test_provider="$2"
    local custom_instance="${3:-}"
    
    debug_log "Initializing test isolation for: $test_name ($test_provider)"
    
    # Create unique temporary directory for this test session
    ISOLATION_TEMP_DIR=$(mktemp -d "/tmp/repocli-test-${test_name}-XXXXXX")
    ISOLATION_BACKUP_DIR="$ISOLATION_TEMP_DIR/backups"
    mkdir -p "$ISOLATION_BACKUP_DIR"
    
    # Store isolation state
    ISOLATION_STATE["test_name"]="$test_name"
    ISOLATION_STATE["provider"]="$test_provider"
    ISOLATION_STATE["custom_instance"]="$custom_instance"
    ISOLATION_STATE["temp_dir"]="$ISOLATION_TEMP_DIR"
    ISOLATION_STATE["backup_dir"]="$ISOLATION_BACKUP_DIR"
    ISOLATION_ACTIVE=true
    
    debug_log "Isolation initialized - Temp dir: $ISOLATION_TEMP_DIR"
    
    # Set up cleanup trap
    trap 'cleanup_test_isolation' EXIT INT TERM
    
    return 0
}

# Backup existing user configurations before test
# Preserves all configuration files that might be affected
backup_user_configs() {
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        echo "Error: Test isolation not initialized" >&2
        return 1
    fi
    
    debug_log "Backing up user configurations"
    
    local backup_count=0
    
    # Backup each configuration file location
    for config_path in "${ISOLATION_CONFIG_LOCATIONS[@]}"; do
        # Expand tilde in path
        local expanded_path="${config_path/#\~/$HOME}"
        
        if [[ -f "$expanded_path" ]]; then
            local backup_name
            backup_name=$(echo "$expanded_path" | sed 's|/|_|g' | sed 's/^_//')
            local backup_file="$ISOLATION_BACKUP_DIR/${backup_name}.backup"
            
            cp "$expanded_path" "$backup_file"
            debug_log "Backed up: $expanded_path -> $backup_file"
            
            # Track backed up files
            ISOLATION_STATE["backup_${backup_count}"]="$expanded_path|$backup_file"
            ((backup_count++))
        fi
    done
    
    ISOLATION_STATE["backup_count"]="$backup_count"
    debug_log "Backed up $backup_count configuration files"
    
    return 0
}

# Create isolated test configuration
# Generates temporary configuration that doesn't affect user settings
# Args: provider [instance] [additional_config]
create_isolated_config() {
    local provider="$1"
    local instance="${2:-}"
    local additional_config="${3:-}"
    
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        echo "Error: Test isolation not initialized" >&2
        return 1
    fi
    
    debug_log "Creating isolated config for provider: $provider"
    
    # Create isolated configuration file in temp directory
    local isolated_config="$ISOLATION_TEMP_DIR/repocli.conf"
    
    # Generate configuration content
    {
        echo "# REPOCLI Test Configuration (Isolated)"
        echo "# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "# Test: ${ISOLATION_STATE[test_name]}"
        echo "provider=$provider"
        
        if [[ -n "$instance" ]]; then
            echo "instance=$instance"
        fi
        
        # Add any additional configuration
        if [[ -n "$additional_config" ]]; then
            echo ""
            echo "# Additional test configuration"
            echo "$additional_config"
        fi
    } > "$isolated_config"
    
    ISOLATION_STATE["isolated_config"]="$isolated_config"
    debug_log "Isolated config created: $isolated_config"
    
    return 0
}

# Activate test isolation
# Replaces user configurations with isolated test configuration
activate_test_isolation() {
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        echo "Error: Test isolation not initialized" >&2
        return 1
    fi
    
    debug_log "Activating test isolation"
    
    # First backup existing configurations
    backup_user_configs
    
    # Remove existing configurations (they are backed up)
    for config_path in "${ISOLATION_CONFIG_LOCATIONS[@]}"; do
        local expanded_path="${config_path/#\~/$HOME}"
        if [[ -f "$expanded_path" ]]; then
            rm -f "$expanded_path"
            debug_log "Removed user config: $expanded_path"
        fi
    done
    
    # Install isolated configuration as project-specific config
    if [[ -n "${ISOLATION_STATE[isolated_config]:-}" ]]; then
        cp "${ISOLATION_STATE[isolated_config]}" "./repocli.conf"
        debug_log "Installed isolated config as ./repocli.conf"
        
        # Track that we created this file
        ISOLATION_STATE["created_project_config"]="true"
    fi
    
    # Set environment variables for custom instances
    local instance="${ISOLATION_STATE[custom_instance]:-}"
    local provider="${ISOLATION_STATE[provider]:-}"
    
    if [[ -n "$instance" && "$provider" == "gitlab" ]]; then
        # Extract hostname from full URL if needed
        local hostname
        if [[ "$instance" =~ ^https?:// ]]; then
            hostname=$(echo "$instance" | sed -E 's|^https?://([^/]+).*|\1|')
        else
            hostname="$instance"
        fi
        
        export GITLAB_HOST="$hostname"
        ISOLATION_STATE["gitlab_host_set"]="$hostname"
        debug_log "Set GITLAB_HOST=$hostname for custom instance"
    fi
    
    debug_log "Test isolation activated successfully"
    return 0
}

# Deactivate test isolation
# Restores original user configurations and cleans up temporary files
deactivate_test_isolation() {
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        debug_log "Test isolation not active, nothing to deactivate"
        return 0
    fi
    
    debug_log "Deactivating test isolation"
    
    # Remove isolated project config if we created it
    if [[ "${ISOLATION_STATE[created_project_config]:-}" == "true" ]]; then
        rm -f "./repocli.conf"
        debug_log "Removed isolated project config"
    fi
    
    # Restore backed up configurations
    local backup_count="${ISOLATION_STATE[backup_count]:-0}"
    for ((i=0; i<backup_count; i++)); do
        local backup_info="${ISOLATION_STATE[backup_${i}]:-}"
        if [[ -n "$backup_info" ]]; then
            local original_path="${backup_info%|*}"
            local backup_file="${backup_info#*|}"
            
            if [[ -f "$backup_file" ]]; then
                # Ensure parent directory exists
                mkdir -p "$(dirname "$original_path")"
                mv "$backup_file" "$original_path"
                debug_log "Restored: $backup_file -> $original_path"
            fi
        fi
    done
    
    # Unset environment variables
    if [[ -n "${ISOLATION_STATE[gitlab_host_set]:-}" ]]; then
        unset GITLAB_HOST
        debug_log "Unset GITLAB_HOST environment variable"
    fi
    
    debug_log "Test isolation deactivated"
    return 0
}

# Complete cleanup of test isolation
# Removes all temporary files and resets isolation state
cleanup_test_isolation() {
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        return 0
    fi
    
    debug_log "Cleaning up test isolation"
    
    # Deactivate isolation first
    deactivate_test_isolation
    
    # Clean up temporary directory
    if [[ -n "$ISOLATION_TEMP_DIR" && -d "$ISOLATION_TEMP_DIR" ]]; then
        rm -rf "$ISOLATION_TEMP_DIR"
        debug_log "Removed temporary directory: $ISOLATION_TEMP_DIR"
    fi
    
    # Reset isolation state
    unset ISOLATION_STATE
    declare -A ISOLATION_STATE
    ISOLATION_TEMP_DIR=""
    ISOLATION_BACKUP_DIR=""
    ISOLATION_ACTIVE=false
    
    # Remove cleanup trap
    trap - EXIT INT TERM
    
    debug_log "Test isolation cleanup completed"
    return 0
}

# Get current isolation status
# Returns information about the current isolation state
get_isolation_status() {
    if [[ "$ISOLATION_ACTIVE" == "true" ]]; then
        echo "Test Isolation Status: ACTIVE"
        echo "Test Name: ${ISOLATION_STATE[test_name]:-unknown}"
        echo "Provider: ${ISOLATION_STATE[provider]:-unknown}"
        echo "Temp Directory: ${ISOLATION_STATE[temp_dir]:-none}"
        echo "Backups: ${ISOLATION_STATE[backup_count]:-0} files"
        
        if [[ -n "${ISOLATION_STATE[custom_instance]:-}" ]]; then
            echo "Custom Instance: ${ISOLATION_STATE[custom_instance]}"
        fi
        
        if [[ -n "${ISOLATION_STATE[gitlab_host_set]:-}" ]]; then
            echo "GITLAB_HOST: ${ISOLATION_STATE[gitlab_host_set]}"
        fi
    else
        echo "Test Isolation Status: INACTIVE"
    fi
    
    return 0
}

# Execute command in isolated environment
# Runs a command with the isolated configuration active
# Args: command [args...]
execute_isolated() {
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        echo "Error: Test isolation not initialized" >&2
        return 1
    fi
    
    debug_log "Executing in isolation: $*"
    
    # Ensure isolation is active
    if [[ ! -f "./repocli.conf" ]]; then
        echo "Error: Isolated configuration not active" >&2
        return 1
    fi
    
    # Execute the command
    "$@"
}

# Validate isolation environment
# Checks that isolation is properly configured and active
validate_isolation() {
    if [[ "$ISOLATION_ACTIVE" != "true" ]]; then
        echo "Error: Test isolation not active"
        return 1
    fi
    
    # Check temporary directory exists
    if [[ ! -d "$ISOLATION_TEMP_DIR" ]]; then
        echo "Error: Isolation temp directory missing: $ISOLATION_TEMP_DIR"
        return 1
    fi
    
    # Check backup directory exists
    if [[ ! -d "$ISOLATION_BACKUP_DIR" ]]; then
        echo "Error: Isolation backup directory missing: $ISOLATION_BACKUP_DIR"
        return 1
    fi
    
    # Check isolated config exists
    if [[ -n "${ISOLATION_STATE[isolated_config]:-}" ]]; then
        if [[ ! -f "${ISOLATION_STATE[isolated_config]}" ]]; then
            echo "Error: Isolated configuration file missing"
            return 1
        fi
    fi
    
    debug_log "Isolation environment validation passed"
    return 0
}

# Safe test wrapper function
# Executes a test function with automatic isolation setup and cleanup
# Args: test_name provider_name test_function [custom_instance] [additional_config]
run_isolated_test() {
    local test_name="$1"
    local provider="$2" 
    local test_function="$3"
    local custom_instance="${4:-}"
    local additional_config="${5:-}"
    
    debug_log "Running isolated test: $test_name"
    
    # Initialize isolation
    if ! init_test_isolation "$test_name" "$provider" "$custom_instance"; then
        echo "Error: Failed to initialize test isolation"
        return 1
    fi
    
    # Create isolated configuration
    if ! create_isolated_config "$provider" "$custom_instance" "$additional_config"; then
        echo "Error: Failed to create isolated configuration"
        cleanup_test_isolation
        return 1
    fi
    
    # Activate isolation
    if ! activate_test_isolation; then
        echo "Error: Failed to activate test isolation"
        cleanup_test_isolation
        return 1
    fi
    
    # Run the test function
    local test_result=0
    if command -v "$test_function" >/dev/null 2>&1; then
        "$test_function" || test_result=$?
    else
        echo "Error: Test function '$test_function' not found"
        test_result=1
    fi
    
    # Always cleanup, regardless of test result
    cleanup_test_isolation
    
    return $test_result
}