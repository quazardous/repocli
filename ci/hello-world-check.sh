#!/bin/bash
# Hello World CI Handcheck Script
# Simple validation script to test basic CI infrastructure
# This runs before complex Task #30 tests to catch basic issues

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[CI-CHECK]${NC} $1"; }
success() { echo -e "${GREEN}[CI-CHECK]${NC} $1"; }
warning() { echo -e "${YELLOW}[CI-CHECK]${NC} $1"; }
error() { echo -e "${RED}[CI-CHECK]${NC} $1"; }

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_RUN++))
    info "Testing: $test_name"
    
    if eval "$test_command" &>/dev/null; then
        ((TESTS_PASSED++))
        success "✅ $test_name - PASS"
        return 0
    else
        error "❌ $test_name - FAIL"
        return 1
    fi
}

main() {
    info "🧪 Hello World CI Handcheck"
    info "=========================="
    info "Simple validation of CI infrastructure before running complex tests"
    info ""
    
    # Basic system checks
    run_test "Bash version check" "bash --version"
    run_test "Current directory access" "pwd"
    run_test "Basic file operations" "touch /tmp/ci-test && rm /tmp/ci-test"
    
    # Basic repo structure checks
    run_test "REPOCLI binary exists" "test -f repocli"
    run_test "REPOCLI binary is executable" "test -x repocli"
    run_test "Library directory exists" "test -d lib"
    run_test "Tests directory exists" "test -d tests"
    
    # Basic REPOCLI functionality
    run_test "REPOCLI help works" "./repocli --help"
    run_test "REPOCLI version works" "./repocli --version"
    
    # Basic shell syntax validation (simple)
    run_test "Main script syntax" "bash -n repocli"
    run_test "Config library syntax" "bash -n lib/config.sh"
    run_test "Utils library syntax" "bash -n lib/utils.sh"
    
    # Environment checks
    run_test "jq command available" "command -v jq"
    run_test "find command available" "command -v find"
    run_test "grep command available" "command -v grep"
    
    # Results
    info ""
    info "📊 Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    
    if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
        success "🎉 All basic CI infrastructure checks passed!"
        success "✅ Environment is ready for complex Task #30 tests"
        exit 0
    else
        error "❌ Some basic infrastructure checks failed"
        warning "⚠️  Fix basic issues before running Task #30 tests"
        exit 1
    fi
}

main "$@"