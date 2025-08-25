#!/bin/bash
# GitHub Provider Test Suite

set -euo pipefail

# Get test directory and repocli binary
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOCLI_DIR="$(cd "$TEST_DIR/.." && pwd)"
REPOCLI_BIN="$REPOCLI_DIR/repocli"

# Test GitHub provider functionality
test_github() {
    echo "Testing GitHub provider..."
    
    # Create GitHub test configuration
    cd "$REPOCLI_DIR"
    cat > repocli.conf << EOF
provider=github
EOF
    
    # Test that it tries to use gh CLI
    if $REPOCLI_BIN auth status 2>&1 | grep -E "gh|GitHub|not found"; then
        echo "✅ GitHub provider routing works"
        return 0
    else
        echo "❌ GitHub provider routing failed"
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
    test_github
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi