#!/bin/bash
# Enable Mock CLI Tools for BC Testing
# Task #30 Phase 5 Implementation - PATH-based transparent mock activation
# 
# Usage: source tests/enable-mocks.sh
# Effect: Prepends mock directory to PATH so existing tests use mocks transparently

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCKS_DIR="$SCRIPT_DIR/mocks"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info_mock() { echo -e "${BLUE}[MOCK-ENABLE]${NC} $1"; }
success_mock() { echo -e "${GREEN}[MOCK-ENABLE]${NC} $1"; }
warning_mock() { echo -e "${YELLOW}[MOCK-ENABLE]${NC} $1"; }

# Check if mocks directory exists
if [[ ! -d "$MOCKS_DIR" ]]; then
    warning_mock "Mocks directory not found: $MOCKS_DIR"
    return 1
fi

# Function to enable mocks
enable_repocli_mocks() {
    info_mock "Enabling REPOCLI mock CLI tools for transparent BC testing"
    
    # Export environment variable for scripts to detect mock mode
    export REPOCLI_USE_MOCKS=1
    
    # Prepend mocks directory to PATH (highest precedence)
    if [[ ":$PATH:" != *":$MOCKS_DIR:"* ]]; then
        export PATH="$MOCKS_DIR:$PATH"
        success_mock "✅ Mock CLI tools enabled in PATH"
        info_mock "   - Mock glab: $MOCKS_DIR/glab"
        info_mock "   - Mock gh:   $MOCKS_DIR/gh"
    else
        info_mock "Mock CLI tools already enabled in PATH"
    fi
    
    # Verify mock availability
    if command -v gh >/dev/null 2>&1 && [[ "$(command -v gh)" == "$MOCKS_DIR/gh" ]]; then
        success_mock "✅ Mock gh CLI active"
    else
        warning_mock "⚠️  Mock gh CLI not active"
    fi
    
    if command -v glab >/dev/null 2>&1 && [[ "$(command -v glab)" == "$MOCKS_DIR/glab" ]]; then
        success_mock "✅ Mock glab CLI active"
    else
        warning_mock "⚠️  Mock glab CLI not active"
    fi
    
    info_mock "Mock mode status: REPOCLI_USE_MOCKS=$REPOCLI_USE_MOCKS"
    info_mock "Existing tests will now use mocks transparently"
}

# Function to disable mocks
disable_repocli_mocks() {
    info_mock "Disabling REPOCLI mock CLI tools"
    
    # Remove environment variable
    unset REPOCLI_USE_MOCKS
    
    # Remove mocks directory from PATH
    export PATH=$(echo "$PATH" | sed "s|$MOCKS_DIR:||g" | sed "s|:$MOCKS_DIR||g" | sed "s|$MOCKS_DIR||g")
    
    success_mock "✅ Mock CLI tools disabled"
    info_mock "Tests will now use real CLI tools (if available)"
}

# Function to show mock status
show_mock_status() {
    info_mock "REPOCLI Mock Status"
    info_mock "=================="
    
    if [[ "${REPOCLI_USE_MOCKS:-}" == "1" ]]; then
        success_mock "✅ Mock mode ENABLED"
        
        if command -v gh >/dev/null 2>&1; then
            local gh_path=$(command -v gh)
            if [[ "$gh_path" == "$MOCKS_DIR/gh" ]]; then
                success_mock "✅ gh: Using mock ($gh_path)"
            else
                warning_mock "⚠️  gh: Using real CLI ($gh_path)"
            fi
        else
            warning_mock "⚠️  gh: Not found in PATH"
        fi
        
        if command -v glab >/dev/null 2>&1; then
            local glab_path=$(command -v glab)
            if [[ "$glab_path" == "$MOCKS_DIR/glab" ]]; then
                success_mock "✅ glab: Using mock ($glab_path)"
            else
                warning_mock "⚠️  glab: Using real CLI ($glab_path)"
            fi
        else
            warning_mock "⚠️  glab: Not found in PATH"
        fi
    else
        info_mock "❌ Mock mode DISABLED"
        
        if command -v gh >/dev/null 2>&1; then
            info_mock "✓ gh: $(command -v gh) (real)"
        else
            info_mock "✗ gh: Not found"
        fi
        
        if command -v glab >/dev/null 2>&1; then
            info_mock "✓ glab: $(command -v glab) (real)"
        else
            info_mock "✗ glab: Not found"
        fi
    fi
}

# Automatic activation if REPOCLI_USE_MOCKS=1
if [[ "${REPOCLI_USE_MOCKS:-}" == "1" ]]; then
    enable_repocli_mocks
else
    info_mock "Mock CLI tools available. Use 'enable_repocli_mocks' to activate."
    info_mock "Or set REPOCLI_USE_MOCKS=1 before sourcing this script."
fi

# Export functions for interactive use
export -f enable_repocli_mocks
export -f disable_repocli_mocks
export -f show_mock_status