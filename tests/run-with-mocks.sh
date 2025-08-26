#!/bin/bash
# Run Tests with Mock CLI Tools - Task #30 Phase 5
# Zero modifications to existing tests - only environment variable injection
# 
# Usage: ./tests/run-with-mocks.sh [TEST_SCRIPT] [TEST_ARGS...]
# Effect: Runs any test script with mocks enabled via PATH manipulation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[MOCK-RUNNER]${NC} $1"; }
success() { echo -e "${GREEN}[MOCK-RUNNER]${NC} $1"; }
warning() { echo -e "${YELLOW}[MOCK-RUNNER]${NC} $1"; }
failure() { echo -e "${RED}[MOCK-RUNNER]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MOCKS_DIR="$SCRIPT_DIR/mocks"

show_help() {
    echo "Run Tests with Mock CLI Tools - Task #30 Phase 5"
    echo ""
    echo "Usage: $0 [TEST_SCRIPT] [TEST_ARGS...]"
    echo ""
    echo "Examples:"
    echo "  $0 tests/run-tests.sh                    # Run main test suite with mocks"
    echo "  $0 tests/cross-testing/run-cross-tests.sh # Run cross-tests with mocks"
    echo "  $0 tests/cross-testing/run-gitlab-tests.sh # Run GitLab tests with mocks"
    echo "  $0 tests/cross-testing/run-github-tests.sh # Run GitHub tests with mocks"
    echo ""
    echo "Mock Features:"
    echo "  ✓ Zero modifications to existing tests"
    echo "  ✓ Transparent PATH-based mock activation"
    echo "  ✓ Preserves all original test functionality"
    echo "  ✓ CI-friendly mock responses"
    echo ""
    echo "Environment Variables:"
    echo "  REPOCLI_USE_MOCKS=1     - Automatically set"
    echo "  REPOCLI_DEBUG=1         - Enable debug output"
    echo ""
}

run_test_with_mocks() {
    local test_script="$1"
    shift
    local test_args="$@"
    
    info "🧪 Running test with mock CLI tools enabled"
    info "=========================================="
    info ""
    info "Test script: $test_script"
    if [[ -n "$test_args" ]]; then
        info "Test args:   $test_args"
    fi
    info "Mock dir:    $MOCKS_DIR"
    info ""
    
    # Validate test script exists
    if [[ ! -f "$test_script" ]]; then
        failure "Test script not found: $test_script"
        exit 1
    fi
    
    # Validate mocks directory exists
    if [[ ! -d "$MOCKS_DIR" ]]; then
        failure "Mocks directory not found: $MOCKS_DIR"
        exit 1
    fi
    
    # Set up mock environment
    export REPOCLI_USE_MOCKS=1
    export PATH="$MOCKS_DIR:$PATH"
    
    # Verify mock activation
    local mock_gh_active=false
    local mock_glab_active=false
    
    if command -v gh >/dev/null 2>&1 && [[ "$(command -v gh)" == "$MOCKS_DIR/gh" ]]; then
        mock_gh_active=true
        success "✅ Mock gh CLI active: $(command -v gh)"
    else
        warning "⚠️  Mock gh CLI not active (real CLI or not found)"
    fi
    
    if command -v glab >/dev/null 2>&1 && [[ "$(command -v glab)" == "$MOCKS_DIR/glab" ]]; then
        mock_glab_active=true
        success "✅ Mock glab CLI active: $(command -v glab)"
    else
        warning "⚠️  Mock glab CLI not active (real CLI or not found)"
    fi
    
    info ""
    if [[ "$mock_gh_active" == "true" ]] || [[ "$mock_glab_active" == "true" ]]; then
        success "🎭 Mock CLI tools successfully activated"
    else
        warning "⚠️  No mock CLI tools active - tests will use real CLIs if available"
    fi
    
    info ""
    info "▶️  Executing test script with mocks..."
    info ""
    
    # Execute the test script with all original arguments
    # The script runs in the same environment with mocks in PATH
    if "$test_script" $test_args; then
        info ""
        success "✅ Test completed successfully with mocks"
        return 0
    else
        local exit_code=$?
        info ""
        failure "❌ Test failed with exit code: $exit_code"
        return $exit_code
    fi
}

main() {
    case "${1:-help}" in
        "--help"|"-h"|"help")
            show_help
            exit 0
            ;;
        "")
            failure "Test script required"
            echo ""
            show_help
            exit 1
            ;;
        *)
            # Change to project directory for test execution
            cd "$PROJECT_DIR"
            run_test_with_mocks "$@"
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi