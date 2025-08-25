#!/bin/bash
# GitLab Provider Test Suite

set -euo pipefail

# Get test directory and repocli binary
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOCLI_DIR="$(cd "$TEST_DIR/.." && pwd)"
REPOCLI_BIN="$REPOCLI_DIR/repocli"

# Test GitLab provider functionality
test_gitlab() {
    echo "Testing GitLab provider..."
    
    # Create GitLab test configuration
    cd "$REPOCLI_DIR"
    cat > repocli.conf << EOF
provider=gitlab
EOF
    
    # Test that it tries to use glab CLI
    if $REPOCLI_BIN auth status 2>&1 | grep -E "glab|GitLab|not found"; then
        echo "✅ GitLab provider routing works"
        return 0
    else
        echo "❌ GitLab provider routing failed"
        return 1
    fi
}

# Test GitLab command mapping
test_gitlab_mapping() {
    echo "Testing GitLab command mapping..."
    
    cd "$REPOCLI_DIR"
    cat > repocli.conf << EOF
provider=gitlab
EOF
    
    # Test unsupported command error handling
    if $REPOCLI_BIN issue unsupported 2>&1 | grep -q "Unsupported issue command"; then
        echo "✅ GitLab command validation works"
        return 0
    else
        echo "❌ GitLab command validation failed"
        return 1
    fi
}

# Cleanup
cleanup() {
    cd "$REPOCLI_DIR"
    rm -f repocli.conf
}

# Main execution
main() {
    trap cleanup EXIT
    test_gitlab && test_gitlab_mapping
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi