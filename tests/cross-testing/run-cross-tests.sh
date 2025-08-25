#!/bin/bash
# REPOCLI Cross-Testing Framework
# Tests REPOCLI functionality across multiple Git hosting providers
# Usage: ./run-cross-tests.sh [provider|all] [options]

set -euo pipefail

# Script metadata
VERSION="1.0.0"
FRAMEWORK_NAME="REPOCLI Cross-Testing Framework"

# Colors for output (following existing pattern from run-tests.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get directory paths
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOCLI_DIR="$(cd "$TEST_DIR/../.." && pwd)"
REPOCLI_BIN="$REPOCLI_DIR/repocli"
LIB_DIR="$TEST_DIR/lib"

# Source shared utilities
source "$LIB_DIR/test-utils.sh"
source "$LIB_DIR/provider-utils.sh"

# Logging functions (consistent with existing test suite)
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

# CLI tool availability checking
check_cli_tool_availability() {
    local provider="$1"
    local tool=""
    
    case "$provider" in
        "github") tool="gh" ;;
        "gitlab") tool="glab" ;;
        "gitea") tool="tea" ;;
        "codeberg") tool="tea" ;;
        *) 
            warning "Unknown provider: $provider"
            return 1
            ;;
    esac
    
    if command -v "$tool" &>/dev/null; then
        info "✓ CLI tool '$tool' available for $provider"
        return 0
    else
        warning "✗ CLI tool '$tool' not found for $provider"
        return 1
    fi
}

# Provider test execution
run_provider_tests() {
    local provider="$1"
    local test_dir="$TEST_DIR/${provider}-test"
    
    info "Running tests for provider: $provider"
    
    # Check CLI tool availability
    if ! check_cli_tool_availability "$provider"; then
        warning "Skipping $provider tests - CLI tool not available"
        return 0
    fi
    
    # Check if test directory exists
    if [[ ! -d "$test_dir" ]]; then
        test_fail "Test directory not found: $test_dir"
        return 1
    fi
    
    # Execute provider-specific tests
    local test_scripts=("$test_dir"/*.sh)
    if [[ ${#test_scripts[@]} -eq 0 ]] || [[ ! -f "${test_scripts[0]}" ]]; then
        warning "No test scripts found in $test_dir"
        return 0
    fi
    
    for script in "${test_scripts[@]}"; do
        if [[ -x "$script" ]]; then
            info "Executing: $(basename "$script")"
            if "$script"; then
                test_pass "$(basename "$script") completed successfully"
            else
                test_fail "$(basename "$script") failed"
            fi
        fi
    done
}

# Main test execution orchestration
run_cross_tests() {
    local target="${1:-all}"
    
    echo ""
    echo "🧪 $FRAMEWORK_NAME v$VERSION"
    echo "================================================"
    echo ""
    
    # Validate REPOCLI binary exists
    if [[ ! -f "$REPOCLI_BIN" ]]; then
        failure "REPOCLI binary not found at: $REPOCLI_BIN"
        exit 1
    fi
    
    info "REPOCLI binary: $REPOCLI_BIN"
    info "Test framework: $TEST_DIR"
    echo ""
    
    # Execute tests based on target
    case "$target" in
        "all")
            info "Running tests for all providers..."
            run_provider_tests "github"
            run_provider_tests "gitlab" 
            run_provider_tests "gitlab-custom"
            ;;
        "github"|"gitlab"|"gitlab-custom")
            run_provider_tests "$target"
            ;;
        *)
            failure "Unknown test target: $target"
            failure "Valid targets: all, github, gitlab, gitlab-custom"
            exit 1
            ;;
    esac
    
    # Display results
    echo ""
    echo "📊 Cross-Testing Results"
    echo "========================="
    echo "Tests Run:    $TESTS_RUN"
    echo "Passed:       $TESTS_PASSED"
    echo "Failed:       $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        success "🎉 All cross-tests passed!"
        exit 0
    else
        echo ""
        failure "❌ Some cross-tests failed!"
        exit 1
    fi
}

# Help display
show_help() {
    echo "Usage: $0 [PROVIDER] [OPTIONS]"
    echo ""
    echo "PROVIDERS:"
    echo "  all            Run tests for all providers (default)"
    echo "  github         Run GitHub provider tests only"
    echo "  gitlab         Run GitLab provider tests only"
    echo "  gitlab-custom  Run custom GitLab instance tests only"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h     Show this help message"
    echo "  --version, -v  Show version information"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Run all cross-tests"
    echo "  $0 github            # Test GitHub provider only"
    echo "  $0 gitlab            # Test GitLab provider only"
    echo ""
}

# Handle command line arguments
case "${1:-all}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --version|-v)
        echo "$FRAMEWORK_NAME v$VERSION"
        exit 0
        ;;
    *)
        run_cross_tests "$@"
        ;;
esac