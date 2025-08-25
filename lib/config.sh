#!/bin/bash
# REPOCLI Configuration Management

# Configuration variables
REPOCLI_PROVIDER=""
REPOCLI_CLI_TOOL=""
REPOCLI_INSTANCE=""

# Configuration file locations (in order of preference)
CONFIG_LOCATIONS=(
    "./repocli.conf"
    "$HOME/.repocli.conf"
    "$HOME/.config/repocli/config"
)

# Load configuration from file
load_config() {
    local config_file=""
    
    # Priority order for configuration file selection:
    # 1. CUSTOM_CONFIG_FILE (from --repocli-config CLI option) - highest priority
    # 2. REPOCLI_CONFIG environment variable
    # 3. Standard locations (existing hierarchy)
    
    if [[ -n "${CUSTOM_CONFIG_FILE:-}" ]]; then
        # CLI option specified
        config_file="$CUSTOM_CONFIG_FILE"
        if [[ ! -f "$config_file" ]]; then
            echo "Error: Configuration file specified via --repocli-config does not exist: $config_file" >&2
            exit 1
        fi
        if [[ ! -r "$config_file" ]]; then
            echo "Error: Configuration file specified via --repocli-config is not readable: $config_file" >&2
            exit 1
        fi
    elif [[ -n "${REPOCLI_CONFIG:-}" ]]; then
        # Environment variable specified
        config_file="$REPOCLI_CONFIG"
        if [[ ! -f "$config_file" ]]; then
            echo "Error: Configuration file specified via REPOCLI_CONFIG environment variable does not exist: $config_file" >&2
            exit 1
        fi
        if [[ ! -r "$config_file" ]]; then
            echo "Error: Configuration file specified via REPOCLI_CONFIG environment variable is not readable: $config_file" >&2
            exit 1
        fi
    else
        # Find configuration file from standard locations
        for location in "${CONFIG_LOCATIONS[@]}"; do
            if [[ -f "$location" ]]; then
                config_file="$location"
                break
            fi
        done
        
        # If no config found, return with empty values
        if [[ -z "$config_file" ]]; then
            return 0
        fi
    fi
    
    # Parse configuration file
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        case $key in
            provider) REPOCLI_PROVIDER="$value" ;;
            cli_tool) REPOCLI_CLI_TOOL="$value" ;;
            instance) REPOCLI_INSTANCE="$value" ;;
        esac
    done < "$config_file"
    
    # Auto-detect CLI tool if not specified
    if [[ -z "$REPOCLI_CLI_TOOL" ]]; then
        case $REPOCLI_PROVIDER in
            github) REPOCLI_CLI_TOOL="gh" ;;
            gitlab) REPOCLI_CLI_TOOL="glab" ;;
            gitea|codeberg) REPOCLI_CLI_TOOL="tea" ;;
        esac
    fi
}

# Interactive configuration initialization
init_config() {
    echo "🔧 REPOCLI Configuration"
    echo "========================"
    echo ""
    echo "Select your Git hosting provider:"
    echo "1. GitHub (gh)"
    echo "2. GitLab (glab)"  
    echo "3. Gitea (tea)"
    echo "4. Codeberg (tea)"
    echo ""
    read -p "Enter choice [1-4]: " choice
    
    local provider=""
    case $choice in
        1) provider="github" ;;
        2) provider="gitlab" ;;
        3) provider="gitea" ;;
        4) provider="codeberg" ;;
        *) 
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    echo ""
    echo "Selected provider: $provider"
    
    # Get additional configuration based on provider
    local instance=""
    case $provider in
        gitlab)
            echo ""
            read -p "Is this a self-hosted GitLab instance? (y/n): " selfhosted
            if [[ "$selfhosted" =~ ^[Yy] ]]; then
                read -p "Enter GitLab instance URL: " instance
                # Validate URL format
                if [[ ! "$instance" =~ ^https?:// ]]; then
                    echo "Error: URL must start with http:// or https://"
                    exit 1
                fi
            fi
            ;;
        gitea)
            read -p "Enter Gitea instance URL: " instance
            if [[ ! "$instance" =~ ^https?:// ]]; then
                echo "Error: URL must start with http:// or https://"
                exit 1
            fi
            ;;
        codeberg)
            instance="https://codeberg.org"
            ;;
    esac
    
    # Choose configuration file location
    echo ""
    echo "Choose configuration location:"
    echo "1. Project-specific (./repocli.conf)"
    echo "2. User-specific (~/.repocli.conf)"
    echo ""
    read -p "Enter choice [1-2]: " config_choice
    
    local config_file=""
    case $config_choice in
        1) config_file="./repocli.conf" ;;
        2) config_file="$HOME/.repocli.conf" ;;
        *) 
            echo "Invalid choice. Using project-specific."
            config_file="./repocli.conf"
            ;;
    esac
    
    # Create configuration file
    {
        echo "# REPOCLI Configuration"
        echo "# Generated on $(date)"
        echo "provider=$provider"
        if [[ -n "$instance" ]]; then
            echo "instance=$instance"
        fi
        echo ""
        echo "# Uncomment to override auto-detected CLI tool"
        case $provider in
            github) echo "#cli_tool=gh" ;;
            gitlab) echo "#cli_tool=glab" ;;
            gitea|codeberg) echo "#cli_tool=tea" ;;
        esac
    } > "$config_file"
    
    echo ""
    echo "✅ Configuration saved to: $config_file"
    echo ""
    echo "Next steps:"
    case $provider in
        github)
            echo "1. Install GitHub CLI: https://cli.github.com/"
            echo "2. Authenticate: gh auth login"
            ;;
        gitlab)
            echo "1. Install GitLab CLI: https://gitlab.com/gitlab-org/cli"
            echo "2. Authenticate: glab auth login"
            ;;
        gitea|codeberg)
            echo "1. Install Tea CLI: https://gitea.com/gitea/tea"
            echo "2. Authenticate: tea login add"
            ;;
    esac
    echo "3. Test: repocli auth status"
}

# Get current configuration file path
get_config_file() {
    for location in "${CONFIG_LOCATIONS[@]}"; do
        if [[ -f "$location" ]]; then
            echo "$location"
            return 0
        fi
    done
    return 1
}