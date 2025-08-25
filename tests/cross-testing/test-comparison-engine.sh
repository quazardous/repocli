#!/bin/bash
# Test script for JSON Output Comparison Engine
# Validates functionality using sample GitHub and GitLab JSON data

set -euo pipefail

# Get paths
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$TEST_DIR/lib"
TEST_DATA_DIR="$TEST_DIR/test-data"

# Source the comparison engine
source "$LIB_DIR/output-comparison.sh"

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

# Test logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
failure() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

run_test() {
    ((TESTS_RUN++))
    local test_name="$1"
    shift
    
    info "Running test: $test_name"
    if "$@"; then
        success "$test_name"
    else
        failure "$test_name"
    fi
    echo ""
}

# ==============================================================================
# Test Functions
# ==============================================================================

test_json_validation() {
    # Test valid JSON file
    if validate_json_input "$TEST_DATA_DIR/github-issue.json" "GitHub Issue" >/dev/null 2>&1; then
        echo "✅ Valid JSON file validation"
    else
        echo "❌ Valid JSON file validation"
        return 1
    fi
    
    # Test valid JSON string
    local valid_json='{"test": "value"}'
    if validate_json_input "$valid_json" "JSON String" >/dev/null 2>&1; then
        echo "✅ Valid JSON string validation"
    else
        echo "❌ Valid JSON string validation"
        return 1
    fi
    
    # Test invalid JSON
    local invalid_json='{"test": invalid}'
    if ! validate_json_input "$invalid_json" "Invalid JSON" >/dev/null 2>&1; then
        echo "✅ Invalid JSON detection"
    else
        echo "❌ Invalid JSON detection"
        return 1
    fi
    
    return 0
}

test_json_normalization() {
    info "Testing JSON normalization..."
    
    # Test file normalization
    local normalized
    normalized=$(normalize_json "$TEST_DATA_DIR/github-issue.json")
    if [[ -n "$normalized" ]] && echo "$normalized" | jq -e . >/dev/null 2>&1; then
        success "JSON file normalization"
    else
        failure "JSON file normalization"
        return 1
    fi
    
    # Test string normalization
    local test_json='{"b": 2, "a": 1}'
    local expected='{"a":1,"b":2}'
    normalized=$(normalize_json "$test_json")
    if [[ "$normalized" == "$expected" ]]; then
        success "JSON string normalization and sorting"
    else
        failure "JSON string normalization and sorting"
        echo "Expected: $expected"
        echo "Got: $normalized"
        return 1
    fi
    
    return 0
}

test_field_mapping() {
    info "Testing field mapping..."
    
    # Test GitHub to GitLab mapping
    local github_json='{"body": "test content", "html_url": "https://github.com/test", "number": 42}'
    local mapped
    mapped=$(map_github_to_gitlab_fields "$github_json")
    
    # Check that fields were mapped correctly
    if echo "$mapped" | jq -e '.description' >/dev/null && \
       echo "$mapped" | jq -e '.web_url' >/dev/null && \
       echo "$mapped" | jq -e '.iid' >/dev/null; then
        success "GitHub to GitLab field mapping"
    else
        failure "GitHub to GitLab field mapping"
        echo "Mapped JSON: $mapped"
        return 1
    fi
    
    return 0
}

test_semantic_comparison() {
    info "Testing semantic comparison..."
    
    # Test identical comparison
    local json1='{"a": 1, "b": 2}'
    local json2='{"b": 2, "a": 1}'  # Different order, same content
    
    if compare_json_semantic "$json1" "$json2"; then
        local result=$?
        if [[ $result -eq $COMPARISON_IDENTICAL ]]; then
            success "Identical JSON comparison"
        else
            failure "Identical JSON comparison - wrong result code: $result"
            return 1
        fi
    else
        failure "Identical JSON comparison failed"
        return 1
    fi
    
    # Test different comparison
    local json3='{"a": 1, "b": 3}'
    if compare_json_semantic "$json1" "$json3" >/dev/null 2>&1; then
        local result=$?
        if [[ $result -eq $COMPARISON_DIFFERENT ]]; then
            success "Different JSON comparison"
        else
            failure "Different JSON comparison - wrong result code: $result"
            return 1
        fi
    else
        failure "Different JSON comparison failed"
        return 1
    fi
    
    return 0
}

test_provider_comparison() {
    info "Testing provider-specific comparison..."
    
    # Compare GitHub and GitLab issue data
    if compare_json_outputs "$TEST_DATA_DIR/github-issue.json" "$TEST_DATA_DIR/gitlab-issue.json" \
                            --type "github-to-gitlab" --format "silent"; then
        local result=$?
        if [[ $result -eq $COMPARISON_EQUIVALENT ]] || [[ $result -eq $COMPARISON_IDENTICAL ]]; then
            success "GitHub/GitLab issue comparison"
        else
            failure "GitHub/GitLab issue comparison - result: $result"
            return 1
        fi
    else
        failure "GitHub/GitLab issue comparison failed"
        return 1
    fi
    
    return 0
}

test_command_output_comparison() {
    info "Testing command-specific comparison..."
    
    # Test issue view comparison
    if compare_command_outputs "$TEST_DATA_DIR/github-issue.json" "$TEST_DATA_DIR/gitlab-issue.json" "issue-view"; then
        success "Issue view command comparison"
    else
        local result=$?
        if [[ $result -eq $COMPARISON_EQUIVALENT ]]; then
            success "Issue view command comparison (equivalent)"
        else
            failure "Issue view command comparison"
            return 1
        fi
    fi
    
    return 0
}

test_edge_cases() {
    info "Testing edge cases..."
    
    # Test empty JSON comparison
    local empty1='{}' 
    local empty2='{}'
    if compare_json_semantic "$empty1" "$empty2" >/dev/null 2>&1; then
        local result=$?
        if [[ $result -eq $COMPARISON_IDENTICAL ]]; then
            success "Empty JSON comparison"
        else
            failure "Empty JSON comparison"
            return 1
        fi
    else
        failure "Empty JSON comparison failed"
        return 1
    fi
    
    # Test invalid JSON handling
    local invalid_json='invalid json'
    local valid_json='{"test": "value"}'
    if ! compare_json_semantic "$invalid_json" "$valid_json" >/dev/null 2>&1; then
        local result=$?
        if [[ $result -eq $COMPARISON_ERROR ]]; then
            success "Invalid JSON error handling"
        else
            failure "Invalid JSON error handling"
            return 1
        fi
    else
        failure "Invalid JSON error handling - should have failed"
        return 1
    fi
    
    return 0
}

test_report_generation() {
    info "Testing report generation..."
    
    local temp_report
    temp_report=$(mktemp)
    
    # Generate comparison report
    if generate_comparison_report '{"a":1}' '{"b":2}' "$COMPARISON_DIFFERENT" "$temp_report" "Test Report"; then
        if [[ -f "$temp_report" ]] && [[ -s "$temp_report" ]]; then
            success "Report generation"
        else
            failure "Report generation - file not created or empty"
            rm -f "$temp_report"
            return 1
        fi
    else
        failure "Report generation failed"
        rm -f "$temp_report"
        return 1
    fi
    
    rm -f "$temp_report"
    return 0
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    echo ""
    echo "🧪 JSON Output Comparison Engine Tests"
    echo "======================================="
    echo ""
    
    # Check dependencies
    if ! command -v jq >/dev/null 2>&1; then
        failure "jq is required but not installed"
        exit 1
    fi
    
    # Ensure test data directory exists
    mkdir -p "$TEST_DATA_DIR"
    
    # Run tests
    run_test "JSON Validation" test_json_validation
    run_test "JSON Normalization" test_json_normalization
    run_test "Field Mapping" test_field_mapping
    run_test "Semantic Comparison" test_semantic_comparison
    run_test "Provider Comparison" test_provider_comparison
    run_test "Command Output Comparison" test_command_output_comparison
    run_test "Edge Cases" test_edge_cases  
    run_test "Report Generation" test_report_generation
    
    # Display results
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

# Handle script arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "help"|"--help"|"-h")
        show_comparison_help
        ;;
    *)
        echo "Usage: $0 [run|help]"
        echo ""
        echo "Commands:"
        echo "  run    Run all tests (default)"
        echo "  help   Show comparison engine help"
        exit 1
        ;;
esac