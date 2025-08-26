#!/bin/bash
# REPOCLI Backwards Compatibility Test Runner
# Phase 1: Simple wrapper to existing test infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[BC-TEST]${NC} $1"; }
success() { echo -e "${GREEN}[BC-TEST]${NC} $1"; }
failure() { echo -e "${RED}[BC-TEST]${NC} $1"; }

# Get script directory
CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$CI_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_DIR/tests"

main() {
    info "🔄 REPOCLI Backwards Compatibility Testing"
    info "==========================================="
    info ""
    info "Running existing test infrastructure for BC validation..."
    info ""
    
    # Ensure we're in the project directory
    cd "$PROJECT_DIR"
    
    # Check if the main test runner exists
    if [[ ! -f "$TESTS_DIR/run-tests.sh" ]]; then
        failure "Main test runner not found: $TESTS_DIR/run-tests.sh"
        exit 1
    fi
    
    # Run the existing test suite
    info "Executing main test suite: $TESTS_DIR/run-tests.sh"
    if "$TESTS_DIR/run-tests.sh"; then
        success "✅ Backwards compatibility tests passed"
        exit 0
    else
        failure "❌ Backwards compatibility tests failed"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi