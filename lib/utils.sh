#!/bin/bash
# REPOCLI Utility Functions

# Show help information
show_help() {
    echo "REPOCLI - Universal Git Hosting Provider CLI"
    echo ""
    echo "Usage: repocli [--repocli-config <file>] <command> [args...]"
    echo ""
    echo "Wrapper-specific options:"
    echo "  repocli:init                    Initialize repocli configuration"
    echo "  --repocli-config <file>         Use custom configuration file"
    echo "  --repocli-help                  Show this wrapper help"
    echo "  --repocli-version               Show wrapper version"
    echo ""
    echo "Commands (provider-agnostic):"
    echo "  auth <subcommand>   Authentication operations"
    echo "  issue <subcommand>  Issue management"
    echo "  repo <subcommand>   Repository operations"
    echo ""
    echo "Note: Standard options like --help, --version, and init pass through"
    echo "to the underlying CLI tool (gh, glab, tea)."
    echo ""
    echo "Examples:"
    echo "  repocli repocli:init            # Configure wrapper"
    echo "  repocli --help                  # Show gh/glab/tea help"
    echo "  repocli --version               # Show gh/glab/tea version"
    echo "  repocli auth status             # Check authentication"
    echo "  repocli issue list              # List issues"
    echo "  repocli issue view 123          # View issue #123"
    echo "  repocli issue create --title \"Bug fix\""
    echo ""
    echo "Configuration files (in order of preference):"
    echo "  1. --repocli-config <file>      (highest priority)"
    echo "  2. REPOCLI_CONFIG env variable"
    echo "  3. ./repocli.conf"
    echo "  4. ~/.repocli.conf"
    echo "  5. ~/.config/repocli/config     (lowest priority)"
    echo ""
    echo "Environment Variables:"
    echo "  REPOCLI_CONFIG     Path to configuration file"
    echo "  REPOCLI_DEBUG      Enable debug output (set to 1)"
    echo ""
    echo "Supported providers:"
    echo "  • GitHub (gh)"
    echo "  • GitLab (glab)"
    echo "  • Gitea (tea)"
    echo "  • Codeberg (tea)"
}

# Check if CLI tool is available
check_cli_tool() {
    local tool="$1"
    
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ CLI tool '$tool' not found" >&2
        echo "" >&2
        case "$tool" in
            gh)
                echo "Install GitHub CLI:" >&2
                echo "  https://cli.github.com/" >&2
                ;;
            glab)
                echo "Install GitLab CLI:" >&2
                echo "  https://gitlab.com/gitlab-org/cli" >&2
                ;;
            tea)
                echo "Install Tea CLI:" >&2
                echo "  https://gitea.com/gitea/tea" >&2
                ;;
        esac
        return 1
    fi
    return 0
}

# Validate URL format
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 1
    fi
    return 0
}

# Debug logging (if REPOCLI_DEBUG is set)
debug_log() {
    if [[ "${REPOCLI_DEBUG:-}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Error handling
error_exit() {
    echo "Error: $1" >&2
    exit 1
}