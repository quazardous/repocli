#!/bin/bash
# Comprehensive Backwards Compatibility Test Demonstration
# Task #30 - Validates mock infrastructure and scenario support
#
# This test demonstrates the complete BC testing capability using:
# - Environment variable-based mock activation
# - Scenario-driven mock responses
# - PM system compatibility validation
# - Real-world command patterns

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[BC-TEST]${NC} $1"; }
success() { echo -e "${GREEN}[BC-TEST]${NC} $1"; }
warning() { echo -e "${YELLOW}[BC-TEST]${NC} $1"; }
failure() { echo -e "${RED}[BC-TEST]${NC} $1"; }

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    success "✅ $1"
}

test_fail() {
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    failure "❌ $1"
}

# Test environment variables support
test_env_vars() {
    info "Testing environment variable support..."
    
    # Test GitHub provider with mock
    echo "provider=github" > test-bc-github.conf
    if REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-bc-github.conf --version >/dev/null 2>&1; then
        test_pass "GitHub provider with REPOCLI_BIN_GH works"
    else
        test_fail "GitHub provider with REPOCLI_BIN_GH failed"
    fi
    
    # Test GitLab provider with mock (auth command works reliably)
    echo "provider=gitlab" > test-bc-gitlab.conf
    if REPOCLI_BIN_GLAB="$(pwd)/tests/mocks/glab" ./repocli --repocli-config test-bc-gitlab.conf auth status >/dev/null 2>&1; then
        test_pass "GitLab provider with REPOCLI_BIN_GLAB works"
    else
        test_fail "GitLab provider with REPOCLI_BIN_GLAB failed"
    fi
    
    # Cleanup
    rm -f test-bc-github.conf test-bc-gitlab.conf
}

# Test PM system compatibility patterns
test_pm_compatibility() {
    info "Testing PM system compatibility patterns..."
    
    echo "provider=github" > test-pm-github.conf
    
    # Test silent auth check (PM critical pattern)
    if REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-pm-github.conf auth status &>/dev/null; then
        test_pass "Silent auth check (PM pattern) works"
    else
        test_fail "Silent auth check (PM pattern) failed"
    fi
    
    # Test JSON extraction (PM critical pattern)
    local issue_num
    issue_num=$(REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-pm-github.conf issue create --title "Test Issue" --json number -q .number 2>/dev/null)
    if [[ -n "$issue_num" ]] && [[ "$issue_num" =~ ^[0-9]+$ ]]; then
        test_pass "JSON extraction (--json number -q .number) works: $issue_num"
    else
        test_fail "JSON extraction (--json number -q .number) failed"
    fi
    
    # Test repository info extraction (PM critical pattern)
    local repo_name
    repo_name=$(REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-pm-github.conf repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    if [[ "$repo_name" == "mock-org/mock-repo" ]]; then
        test_pass "Repository info extraction works: $repo_name"
    else
        test_fail "Repository info extraction failed: got '$repo_name'"
    fi
    
    # Test extension detection (PM critical pattern)
    if REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-pm-github.conf extension list 2>/dev/null | grep -q "yahsan2/gh-sub-issue"; then
        test_pass "Extension detection (greppable output) works"
    else
        test_fail "Extension detection (greppable output) failed"
    fi
    
    rm -f test-pm-github.conf
}

# Test GitLab parameter translation
test_gitlab_translation() {
    info "Testing GitLab parameter translation..."
    
    echo "provider=gitlab" > test-gitlab-translation.conf
    
    # Test body-file -> description-file translation
    echo "Test issue body" > test-body.txt
    local result
    result=$(REPOCLI_BIN_GLAB="$(pwd)/tests/mocks/glab" REPOCLI_DEBUG=1 ./repocli --repocli-config test-gitlab-translation.conf issue create --title "Test Issue" --body-file test-body.txt 2>&1)
    if echo "$result" | grep -q "description-file.*correctly translated"; then
        test_pass "Parameter translation (--body-file -> --description-file) works"
    else
        test_fail "Parameter translation (--body-file -> --description-file) failed"
    fi
    
    # Test command mapping (issue comment -> issue note create)
    local note_result
    note_result=$(REPOCLI_BIN_GLAB="$(pwd)/tests/mocks/glab" REPOCLI_DEBUG=1 ./repocli --repocli-config test-gitlab-translation.conf issue comment 123 --body-file test-body.txt 2>&1)
    if echo "$note_result" | grep -q "issue comment.*issue note create"; then
        test_pass "Command mapping (issue comment -> issue note create) works"
    else
        test_fail "Command mapping (issue comment -> issue note create) failed"
    fi
    
    # Test JSON field mapping (GitHub body -> GitLab description)
    local body_content
    body_content=$(REPOCLI_BIN_GLAB="$(pwd)/tests/mocks/glab" ./repocli --repocli-config test-gitlab-translation.conf issue view 123 --json body -q .description 2>/dev/null)
    if [[ "$body_content" == *"description (not body) field"* ]]; then
        test_pass "JSON field mapping (body -> description) works"
    else
        test_fail "JSON field mapping (body -> description) failed: '$body_content'"
    fi
    
    rm -f test-gitlab-translation.conf test-body.txt
}

# Test CI environment detection
test_ci_detection() {
    info "Testing CI environment detection..."
    
    echo "provider=github" > test-ci-github.conf
    
    # Test normal environment (should show authenticated)
    local auth_output
    auth_output=$(REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-ci-github.conf auth status 2>&1)
    if echo "$auth_output" | grep -q "Logged in to github.com"; then
        test_pass "Normal environment shows authenticated state"
    else
        test_fail "Normal environment authentication detection failed"
    fi
    
    # Test CI environment simulation (should show unauthenticated)
    local ci_auth_output
    ci_auth_output=$(CI=1 REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-ci-github.conf auth status 2>&1 || true)
    if echo "$ci_auth_output" | grep -q "error connecting"; then
        test_pass "CI environment shows unauthenticated state"
    else
        test_fail "CI environment authentication simulation failed"
    fi
    
    rm -f test-ci-github.conf
}

# Test scenario support (if implemented)
test_scenarios() {
    info "Testing mock scenario support..."
    
    echo "provider=github" > test-scenarios.conf
    
    # Test basic scenario
    local basic_result
    basic_result=$(REPOCLI_MOCK_SCENARIO=basic REPOCLI_BIN_GH="$(pwd)/tests/mocks/gh" ./repocli --repocli-config test-scenarios.conf issue list --json number 2>/dev/null || echo "[]")
    if [[ "$basic_result" != "[]" ]]; then
        test_pass "Basic scenario support works"
    else
        test_fail "Basic scenario support failed"
    fi
    
    rm -f test-scenarios.conf
}

# Main test execution
main() {
    info "🧪 Comprehensive Backwards Compatibility Test Suite"
    info "================================================="
    info "Task #30 - Mock Infrastructure and Scenario Testing"
    info ""
    
    # Verify mock files exist
    if [[ ! -f "tests/mocks/gh" ]] || [[ ! -f "tests/mocks/glab" ]]; then
        failure "Mock CLI tools not found in tests/mocks/"
        exit 1
    fi
    
    if [[ ! -x "tests/mocks/gh" ]] || [[ ! -x "tests/mocks/glab" ]]; then
        failure "Mock CLI tools are not executable"
        exit 1
    fi
    
    # Run test suites
    test_env_vars
    test_pm_compatibility
    test_gitlab_translation
    test_ci_detection
    test_scenarios
    
    # Results
    info ""
    info "📊 Test Results Summary"
    info "======================"
    info "Tests Run:    $TESTS_RUN"
    info "Passed:       $TESTS_PASSED"
    info "Failed:       $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        info ""
        success "🎉 All backwards compatibility tests passed!"
        success "✅ Mock infrastructure fully functional"
        success "✅ PM system compatibility validated"
        success "✅ Provider translation working"
        success "✅ CI environment detection working"
        exit 0
    else
        info ""
        failure "❌ Some backwards compatibility tests failed!"
        exit 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi