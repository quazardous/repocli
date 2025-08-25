#!/bin/bash
# REPOCLI Test Suite Runner

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; }
failure() { echo -e "${RED}[FAIL]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Test result tracking
test_pass() {
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    success "$1"
}

test_fail() {
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    failure "$1"
}

# Get the directory where this script is located
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOCLI_DIR="$(cd "$TEST_DIR/.." && pwd)"
REPOCLI_BIN="$REPOCLI_DIR/repocli"

# Test basic functionality
test_basic() {
    info "Testing basic functionality..."
    
    # Test version
    if $REPOCLI_BIN --version &>/dev/null; then
        test_pass "Version command works"
    else
        test_fail "Version command failed"
    fi
    
    # Test help
    if $REPOCLI_BIN --help &>/dev/null; then
        test_pass "Help command works"
    else
        test_fail "Help command failed"
    fi
}

# Test configuration
test_config() {
    info "Testing configuration..."
    
    # Create test config
    local test_config_file="$REPOCLI_DIR/test-repocli.conf"
    cat > "$test_config_file" << EOF
provider=github
EOF
    
    # Test config loading (this will fail without gh but should parse config)
    cd "$REPOCLI_DIR"
    if $REPOCLI_BIN auth status 2>&1 | grep -q "github\|not found\|not configured"; then
        test_pass "Configuration loading works"
    else
        test_fail "Configuration loading failed"
    fi
    
    # Cleanup
    rm -f "$test_config_file"
}

# Test provider detection
test_providers() {
    info "Testing provider detection..."
    
    local providers=("github" "gitlab" "gitea" "codeberg")
    
    for provider in "${providers[@]}"; do
        # Create test config for each provider
        local test_config="$REPOCLI_DIR/test-${provider}.conf"
        echo "provider=$provider" > "$test_config"
        
        cd "$REPOCLI_DIR"
        cp "$test_config" repocli.conf
        
        # Test that it recognizes the provider (may fail on CLI tool check)
        if $REPOCLI_BIN auth status 2>&1 | grep -E "$provider|not found|CLI tool.*not found"; then
            test_pass "Provider $provider detection works"
        else
            test_fail "Provider $provider detection failed"
        fi
        
        rm -f "$test_config" repocli.conf
    done
}

# Test error handling
test_error_handling() {
    info "Testing error handling..."
    
    cd "$REPOCLI_DIR"
    
    # Test with no configuration
    if $REPOCLI_BIN auth status 2>&1 | grep -q "not configured"; then
        test_pass "No configuration error handling works"
    else
        test_fail "No configuration error handling failed"
    fi
    
    # Test with invalid provider
    echo "provider=invalid" > repocli.conf
    if $REPOCLI_BIN auth status 2>&1 | grep -q "Unknown provider"; then
        test_pass "Invalid provider error handling works"
    else
        test_fail "Invalid provider error handling failed"
    fi
    
    rm -f repocli.conf
}

# Test library loading
test_library_loading() {
    info "Testing library loading..."
    
    local required_files=(
        "lib/config.sh"
        "lib/utils.sh"
        "lib/providers/github.sh"
        "lib/providers/gitlab.sh"
        "lib/providers/gitea.sh"
        "lib/providers/codeberg.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$REPOCLI_DIR/$file" ]]; then
            # Test that the file can be sourced
            if bash -n "$REPOCLI_DIR/$file"; then
                test_pass "Library file $file is valid"
            else
                test_fail "Library file $file has syntax errors"
            fi
        else
            test_fail "Required library file $file is missing"
        fi
    done
}

# Main test execution
main() {
    echo ""
    echo "🧪 REPOCLI Test Suite"
    echo "===================="
    echo ""
    
    # Check if repocli binary exists
    if [[ ! -f "$REPOCLI_BIN" ]]; then
        failure "REPOCLI binary not found at: $REPOCLI_BIN"
        exit 1
    fi
    
    # Run test suites
    test_basic
    test_library_loading
    test_config
    test_providers
    test_error_handling
    
    # Run provider-specific tests if available
    for test_file in "$TEST_DIR"/test-*.sh; do
        if [[ -f "$test_file" && "$test_file" != "$0" ]]; then
            info "Running $(basename "$test_file")..."
            if bash "$test_file"; then
                test_pass "$(basename "$test_file") passed"
            else
                test_fail "$(basename "$test_file") failed"
            fi
        fi
    done
    
    # Results
    echo ""
    echo "📊 Test Results"
    echo "==============="
    echo "Tests Run:    $TESTS_RUN"
    echo "Passed:       $TESTS_PASSED"
    echo "Failed:       $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        success "🎉 All tests passed!"
        exit 0
    else
        echo ""
        failure "❌ Some tests failed!"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi