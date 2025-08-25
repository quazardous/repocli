#!/bin/bash
# GitHub Provider Cross-Testing Script
# Integrates with the cross-testing framework to run GitHub provider ping checks
# This script is automatically discovered and executed by run-cross-tests.sh

set -euo pipefail

# Get directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
REPOCLI_DIR="/home/david/dev/projects/quazardous/repocli_world/repocli"

# Ensure we use the correct REPOCLI binary (from the main repocli project)
export PATH="$REPOCLI_DIR:$PATH"

# Source GitHub test library
source "$LIB_DIR/github-tests.sh"

# Main test execution
main() {
    echo "🏓 GitHub Provider Cross-Testing"
    echo "================================"
    echo "Location: $(pwd)"
    echo "REPOCLI Path: $REPOCLI_DIR"
    echo ""
    
    # Change to the github-test directory so repocli can find its config
    cd "$SCRIPT_DIR"
    
    # Verify repocli is available
    if ! command -v repocli &>/dev/null; then
        echo "❌ Error: repocli command not found in PATH"
        echo "   PATH: $PATH"
        return 1
    fi
    
    # Verify we're using the right repocli (should be our development version)
    local repocli_path
    repocli_path=$(command -v repocli)
    echo "Using repocli: $repocli_path"
    
    # Test basic repocli functionality
    echo "Testing repocli configuration..."
    if repocli --version >/dev/null 2>&1; then
        echo "✅ repocli is properly configured"
    else
        echo "❌ repocli configuration issue"
        return 1
    fi
    
    # Verify gh CLI is available
    if ! command -v gh &>/dev/null; then
        echo "⚠️  Warning: gh CLI not found - GitHub provider tests will be skipped"
        echo "   Install gh CLI to run these tests: https://cli.github.com/"
        return 0
    fi
    
    local gh_version
    gh_version=$(gh --version | head -1)
    echo "GitHub CLI: $gh_version"
    echo ""
    
    # Run the GitHub tests without isolation (since config is already here)
    run_github_tests
    local test_result=$?
    
    echo ""
    if [[ $test_result -eq 0 ]]; then
        echo "✅ GitHub provider cross-testing completed successfully"
    else
        echo "❌ GitHub provider cross-testing failed"
    fi
    
    return $test_result
}

# Execute main function
main "$@"