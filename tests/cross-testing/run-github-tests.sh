#!/bin/bash
# GitHub Provider Test Runner - Task #5 Implementation
# Uses Task #14 API for provider configuration and testing

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the GitHub tests
source "$SCRIPT_DIR/lib/github-tests.sh"

# Main execution
echo "GitHub Provider Tests - Task #5 Implementation"
echo "=============================================="
echo ""

# Ensure repocli is in PATH
if [[ ":$PATH:" != *":$(pwd):"* ]] && [[ -x "$(pwd)/repocli" ]]; then
    export PATH="$(pwd):$PATH"
    echo "Added current directory to PATH for repocli access"
fi

# Check if repocli is available
if ! command -v repocli >/dev/null 2>&1; then
    echo "Error: repocli command not found in PATH"
    echo "Please ensure repocli is installed or run from the repocli directory"
    exit 1
fi

# Run the GitHub provider tests using task #14 API
run_isolated_github_tests