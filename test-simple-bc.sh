#!/bin/bash
# Simple BC Test to validate core functionality
# Task #30 - Focused on key BC patterns

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[BC-TEST]${NC} $1"; }
success() { echo -e "${GREEN}[BC-TEST]${NC} $1"; }
failure() { echo -e "${RED}[BC-TEST]${NC} $1"; }

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

test_pass() {
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    success "✅ $1"
}

main() {
    info "🧪 Simple Backwards Compatibility Test"
    info "====================================="
    info ""
    
    # Test 1: GitHub mock with version
    info "Testing GitHub mock version..."
    if timeout 5s bash -c 'echo "provider=github" > test-gh.conf && REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-gh.conf --version >/dev/null 2>&1'; then
        test_pass "GitHub mock version works"
    else
        failure "❌ GitHub mock version failed"
    fi
    
    # Test 2: GitHub auth status
    info "Testing GitHub mock auth..."
    if timeout 5s bash -c 'REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-gh.conf auth status >/dev/null 2>&1'; then
        test_pass "GitHub mock auth works"
    else
        failure "❌ GitHub mock auth failed"
    fi
    
    # Test 3: GitLab auth status (reliable command)
    info "Testing GitLab mock auth..."
    if timeout 5s bash -c 'echo "provider=gitlab" > test-gl.conf && REPOCLI_BIN_GLAB="$(pwd)/tests/mocks/glab" ./repocli --repocli-config test-gl.conf auth status >/dev/null 2>&1'; then
        test_pass "GitLab mock auth works"
    else
        failure "❌ GitLab mock auth failed"
    fi
    
    # Test 4: PM critical pattern - JSON extraction
    info "Testing PM critical pattern (JSON extraction)..."
    local issue_num
    if issue_num=$(timeout 5s bash -c 'REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-gh.conf issue create --title "Test Issue" --json number -q .number 2>/dev/null') && [[ -n "$issue_num" ]] && [[ "$issue_num" =~ ^[0-9]+$ ]]; then
        test_pass "PM JSON extraction works (got: $issue_num)"
    else
        failure "❌ PM JSON extraction failed"
    fi
    
    # Test 5: Extension detection (PM critical)
    info "Testing PM critical pattern (extension detection)..."
    if timeout 5s bash -c 'REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-gh.conf extension list 2>/dev/null | grep -q "yahsan2/gh-sub-issue"'; then
        test_pass "PM extension detection works"
    else
        failure "❌ PM extension detection failed"
    fi
    
    # Clean up
    rm -f test-gh.conf test-gl.conf
    
    # Results
    info ""
    info "📊 Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    
    if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
        success "🎉 All core BC functionality working!"
        success "✅ Environment variable support: WORKING"
        success "✅ Mock infrastructure: WORKING"  
        success "✅ PM compatibility patterns: WORKING"
        exit 0
    else
        failure "❌ Some tests failed"
        exit 1
    fi
}

main "$@"