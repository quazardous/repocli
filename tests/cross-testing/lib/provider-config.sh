#!/bin/bash
# Provider Configuration Management for Cross-Testing
# Handles configuration generation, validation, and management for different providers

# Provider configuration templates and utilities
declare -A PROVIDER_CONFIGS
declare -A PROVIDER_CLI_TOOLS
declare -A PROVIDER_DEFAULT_INSTANCES

# Initialize provider configuration data
init_provider_configs() {
    # CLI tool mappings
    PROVIDER_CLI_TOOLS["github"]="gh"
    PROVIDER_CLI_TOOLS["gitlab"]="glab"
    PROVIDER_CLI_TOOLS["gitea"]="tea"
    PROVIDER_CLI_TOOLS["codeberg"]="tea"
    
    # Default instances
    PROVIDER_DEFAULT_INSTANCES["github"]="github.com"
    PROVIDER_DEFAULT_INSTANCES["gitlab"]="gitlab.com"
    PROVIDER_DEFAULT_INSTANCES["gitea"]=""
    PROVIDER_DEFAULT_INSTANCES["codeberg"]="codeberg.org"
    
    # Use debug_log if available, otherwise skip
    if command -v debug_log >/dev/null 2>&1; then
        debug_log "Provider configurations initialized"
    fi
}

# Generate configuration content for a specific provider
# Args: provider [instance] [cli_tool] [additional_options]
generate_provider_config() {
    local provider="$1"
    local instance="${2:-}"
    local cli_tool="${3:-}"
    local additional_options="${4:-}"
    
    debug_log "Generating config for provider: $provider"
    
    # Initialize provider data if not done
    if [[ -z "${PROVIDER_CLI_TOOLS[$provider]:-}" ]]; then
        init_provider_configs
    fi
    
    # Validate provider
    if [[ -z "${PROVIDER_CLI_TOOLS[$provider]:-}" ]]; then
        echo "Error: Unknown provider: $provider" >&2
        return 1
    fi
    
    # Use default CLI tool if not specified
    if [[ -z "$cli_tool" ]]; then
        cli_tool="${PROVIDER_CLI_TOOLS[$provider]}"
    fi
    
    # Generate configuration content
    local config_content=""
    config_content+="# REPOCLI Test Configuration\n"
    config_content+="# Provider: $provider\n"
    config_content+="# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n"
    config_content+="\n"
    config_content+="provider=$provider\n"
    
    # Add instance if specified
    if [[ -n "$instance" ]]; then
        config_content+="instance=$instance\n"
    fi
    
    # Add CLI tool if different from default
    if [[ "$cli_tool" != "${PROVIDER_CLI_TOOLS[$provider]}" ]]; then
        config_content+="cli_tool=$cli_tool\n"
    fi
    
    # Add additional options
    if [[ -n "$additional_options" ]]; then
        config_content+="\n"
        config_content+="# Additional configuration\n"
        config_content+="$additional_options\n"
    fi
    
    # Output the configuration
    echo -e "$config_content"
    return 0
}

# Create temporary configuration file
# Args: provider [instance] [cli_tool] [additional_options] [output_file]
create_temp_config() {
    local provider="$1"
    local instance="${2:-}"
    local cli_tool="${3:-}"
    local additional_options="${4:-}"
    local output_file="${5:-}"
    
    debug_log "Creating temp config for provider: $provider"
    
    # Generate temporary file name if not provided
    if [[ -z "$output_file" ]]; then
        output_file=$(mktemp "/tmp/repocli-config-${provider}-XXXXXX.conf")
    fi
    
    # Generate and write configuration
    if ! generate_provider_config "$provider" "$instance" "$cli_tool" "$additional_options" > "$output_file"; then
        rm -f "$output_file"
        return 1
    fi
    
    debug_log "Temp config created: $output_file"
    echo "$output_file"
    return 0
}

# Validate provider configuration file
# Args: config_file
validate_provider_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found: $config_file"
        return 1
    fi
    
    debug_log "Validating config file: $config_file"
    
    # Check for required provider field
    local provider
    provider=$(grep "^provider=" "$config_file" | cut -d'=' -f2 | xargs)
    
    if [[ -z "$provider" ]]; then
        echo "Error: No provider specified in configuration"
        return 1
    fi
    
    # Initialize provider data if needed
    if [[ -z "${PROVIDER_CLI_TOOLS[$provider]:-}" ]]; then
        init_provider_configs
    fi
    
    # Validate provider is supported
    if [[ -z "${PROVIDER_CLI_TOOLS[$provider]:-}" ]]; then
        echo "Error: Unsupported provider: $provider"
        return 1
    fi
    
    # Check for instance field if provider requires it
    local instance
    instance=$(grep "^instance=" "$config_file" | cut -d'=' -f2 | xargs)
    
    # Validate instance format for providers that use custom instances
    if [[ -n "$instance" ]]; then
        case "$provider" in
            "gitlab"|"gitea")
                # Check if it looks like a URL or hostname
                if [[ ! "$instance" =~ ^https?:// ]] && [[ ! "$instance" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                    echo "Error: Invalid instance format: $instance"
                    return 1
                fi
                ;;
        esac
    fi
    
    debug_log "Configuration validation passed"
    return 0
}

# Get provider-specific test repository
# Args: provider [instance]
get_provider_test_repository() {
    local provider="$1"
    local instance="${2:-}"
    
    case "$provider" in
        "github")
            echo "microsoft/vscode"
            ;;
        "gitlab")
            if [[ -n "$instance" && "$instance" != "gitlab.com" ]]; then
                # For custom GitLab instances, use a generic path
                echo "root/test-project"
            else
                echo "gitlab-org/gitlab"
            fi
            ;;
        "gitea")
            echo "gitea/tea"
            ;;
        "codeberg")
            echo "forgejo/forgejo"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get provider authentication command
# Args: provider
get_provider_auth_command() {
    local provider="$1"
    
    # Initialize provider data if needed
    if [[ -z "${PROVIDER_CLI_TOOLS[$provider]:-}" ]]; then
        init_provider_configs
    fi
    
    local cli_tool="${PROVIDER_CLI_TOOLS[$provider]:-}"
    if [[ -z "$cli_tool" ]]; then
        echo ""
        return 1
    fi
    
    echo "$cli_tool auth status"
    return 0
}

# Create configuration for specific test scenarios
# Args: scenario_name
create_scenario_config() {
    local scenario="$1"
    
    debug_log "Creating config for scenario: $scenario"
    
    case "$scenario" in
        "github-standard")
            generate_provider_config "github"
            ;;
        "gitlab-standard")
            generate_provider_config "gitlab"
            ;;
        "gitlab-custom")
            local instance="${GITLAB_TEST_INSTANCE:-gitlab.example.com}"
            generate_provider_config "gitlab" "$instance"
            ;;
        "gitea-custom")
            local instance="${GITEA_TEST_INSTANCE:-gitea.example.com}"
            generate_provider_config "gitea" "$instance"
            ;;
        "codeberg-standard")
            generate_provider_config "codeberg" "https://codeberg.org"
            ;;
        *)
            echo "Error: Unknown scenario: $scenario" >&2
            return 1
            ;;
    esac
}

# Expand configuration variables
# Processes environment variable substitutions in configuration values
# Args: config_string
expand_config_variables() {
    local config_string="$1"
    
    # Handle common environment variable patterns
    # ${VAR:-default} syntax
    config_string=$(echo "$config_string" | sed -E 's/\$\{([A-Z_]+):-([^}]+)\}/$(eval "echo \${$1:-$2}")/g')
    
    # Simple $VAR syntax
    config_string=$(eval "echo \"$config_string\"")
    
    echo "$config_string"
}

# Load and process configuration template
# Args: template_file output_file
process_config_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template file not found: $template_file"
        return 1
    fi
    
    debug_log "Processing config template: $template_file -> $output_file"
    
    # Process the template, expanding variables
    while IFS= read -r line; do
        # Skip comments and empty lines in processing
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            echo "$line"
        else
            # Expand variables in the line
            expanded_line=$(expand_config_variables "$line")
            echo "$expanded_line"
        fi
    done < "$template_file" > "$output_file"
    
    debug_log "Template processed successfully"
    return 0
}

# Generate environment-specific configuration
# Args: provider environment [custom_vars]
generate_environment_config() {
    local provider="$1"
    local environment="$2"  # e.g., "test", "staging", "custom"
    local custom_vars="${3:-}"
    
    debug_log "Generating environment config: $provider/$environment"
    
    local config_content=""
    config_content+="# REPOCLI Environment Configuration\n"
    config_content+="# Provider: $provider\n"
    config_content+="# Environment: $environment\n"
    config_content+="# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n"
    config_content+="\n"
    config_content+="provider=$provider\n"
    
    # Add environment-specific settings
    case "$environment" in
        "test")
            config_content+="# Test environment settings\n"
            case "$provider" in
                "gitlab")
                    local instance="${GITLAB_TEST_INSTANCE:-gitlab.example.com}"
                    if [[ "$instance" != "gitlab.com" ]]; then
                        config_content+="instance=$instance\n"
                    fi
                    ;;
                "gitea")
                    config_content+="instance=\${GITEA_TEST_INSTANCE:-gitea.example.com}\n"
                    ;;
            esac
            ;;
        "staging")
            config_content+="# Staging environment settings\n"
            case "$provider" in
                "gitlab")
                    config_content+="instance=\${GITLAB_STAGING_INSTANCE:-gitlab-staging.example.com}\n"
                    ;;
            esac
            ;;
        "custom")
            config_content+="# Custom environment settings\n"
            if [[ -n "$custom_vars" ]]; then
                config_content+="$custom_vars\n"
            fi
            ;;
    esac
    
    echo -e "$config_content"
    return 0
}

# Backup existing configuration files
# Args: backup_directory
backup_existing_configs() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
    fi
    
    debug_log "Backing up existing configurations to: $backup_dir"
    
    local backup_count=0
    local config_locations=(
        "./repocli.conf"
        "$HOME/.repocli.conf"
        "$HOME/.config/repocli/config"
    )
    
    for config_path in "${config_locations[@]}"; do
        local expanded_path="${config_path/#\~/$HOME}"
        
        if [[ -f "$expanded_path" ]]; then
            local backup_name
            backup_name=$(echo "$expanded_path" | sed 's|/|_|g' | sed 's/^_//')
            local backup_file="$backup_dir/${backup_name}.backup"
            
            cp "$expanded_path" "$backup_file"
            debug_log "Backed up: $expanded_path -> $backup_file"
            ((backup_count++))
        fi
    done
    
    echo "$backup_count"
    return 0
}

# Restore configuration files from backup
# Args: backup_directory
restore_config_backups() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        debug_log "Backup directory not found: $backup_dir"
        return 0
    fi
    
    debug_log "Restoring configurations from: $backup_dir"
    
    local restore_count=0
    
    # Find all backup files
    for backup_file in "$backup_dir"/*.backup; do
        if [[ -f "$backup_file" ]]; then
            # Extract original path from backup filename
            local backup_name
            backup_name=$(basename "$backup_file" .backup)
            local original_path
            original_path=$(echo "$backup_name" | sed 's/_/\//g')
            
            # Handle home directory prefix
            if [[ "$original_path" =~ ^home/ ]]; then
                original_path="/$original_path"
            elif [[ "$original_path" == "repocli.conf" ]]; then
                original_path="./repocli.conf"
            fi
            
            # Ensure parent directory exists
            local parent_dir
            parent_dir=$(dirname "$original_path")
            if [[ "$parent_dir" != "." ]]; then
                mkdir -p "$parent_dir"
            fi
            
            # Restore the file
            cp "$backup_file" "$original_path"
            debug_log "Restored: $backup_file -> $original_path"
            ((restore_count++))
        fi
    done
    
    echo "$restore_count"
    return 0
}

# Initialize provider configurations on script load
init_provider_configs