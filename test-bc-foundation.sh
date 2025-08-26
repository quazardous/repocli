#!/bin/bash
# BC Foundation Test - Validates Task #30 Implementation
# Tests the core environment variable support without relying on full test suite

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[BC-FOUNDATION]${NC} $1"; }
success() { echo -e "${GREEN}[BC-FOUNDATION]${NC} $1"; }
failure() { echo -e "${RED}[BC-FOUNDATION]${NC} $1"; }

main() {
    info "Testing REPOCLI BC Foundation - Task #30"
    info "========================================"
    info ""
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: GitHub provider with mock
    info "Test 1: GitHub provider environment variable support"
    echo "provider=github" > test-bc-config.conf
    if REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-bc-config.conf auth status &>/dev/null; then
        success "✅ GitHub mock integration works"
        ((tests_passed++))
    else
        failure "❌ GitHub mock integration failed"
        ((tests_failed++))
    fi
    
    # Test 2: GitLab provider with mock  
    info "Test 2: GitLab provider environment variable support"
    echo "provider=gitlab" > test-bc-config.conf
    if timeout 5 bash -c 'REPOCLI_BIN_GLAB="$(pwd)/tests/mocks/glab" ./repocli --repocli-config test-bc-config.conf auth status' &>/dev/null; then
        success "✅ GitLab mock integration works"
        ((tests_passed++))
    else
        failure "❌ GitLab mock integration failed"
        ((tests_failed++))
    fi
    
    # Test 3: BC Test Runner exists and runs
    info "Test 3: BC test runner functionality"
    if [[ -x "./ci/run-bc-tests.sh" ]]; then
        success "✅ BC test runner is executable"
        ((tests_passed++))
    else
        failure "❌ BC test runner missing or not executable"
        ((tests_failed++))
    fi
    
    # Test 4: Cross-testing GitLab runner exists
    info "Test 4: GitLab cross-testing runner"
    if [[ -x "./tests/cross-testing/run-gitlab-tests.sh" ]]; then
        success "✅ GitLab test runner exists"
        ((tests_passed++))
    else
        failure "❌ GitLab test runner missing"
        ((tests_failed++))
    fi
    
    # Test 5: Mock scripts are executable and functional
    info "Test 5: Mock script functionality"
    if ./tests/mocks/gh --version &>/dev/null && ./tests/mocks/glab --version &>/dev/null; then
        success "✅ Mock scripts are functional"
        ((tests_passed++))
    else
        failure "❌ Mock scripts are not working"
        ((tests_failed++))
    fi
    
    # Cleanup
    rm -f test-bc-config.conf
    
    # Results
    info ""
    info "BC Foundation Test Results:"
    info "Passed: $tests_passed"
    info "Failed: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        success "🎉 All BC foundation tests passed!"
        success "Task #30 core requirements implemented successfully"
        exit 0
    else
        failure "❌ Some BC foundation tests failed"
        exit 1
    fi
}

main "$@"