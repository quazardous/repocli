#!/bin/bash
# Basic REPOCLI configuration validation tests for backwards compatibility
# Task #30: CI/Test Runner Foundation

# Source test configuration utilities
source "$(dirname "${BASH_SOURCE[0]}")/test-config.sh"

# Test basic REPOCLI configuration loading
test_basic_config_loading() {
    echo "🔧 Testing basic configuration loading..."
    
    # Test 1: REPOCLI_CONFIG environment variable
    local temp_config=$(mktemp)
    echo "provider=github" > "$temp_config"
    REPOCLI_CONFIG="$temp_config" repocli --repocli-version >/dev/null 2>&1
    local exit_code=$?
    rm -f "$temp_config"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "✅ REPOCLI_CONFIG environment variable works"
    else
        echo "❌ REPOCLI_CONFIG environment variable failed"
        return 1
    fi
    
    # Test 2: Provider selection validation
    local temp_config2=$(mktemp)
    echo "provider=invalid_provider" > "$temp_config2"
    REPOCLI_CONFIG="$temp_config2" repocli --repocli-version >/dev/null 2>&1
    local exit_code2=$?
    rm -f "$temp_config2"
    
    if [[ $exit_code2 -ne 0 ]]; then
        echo "✅ Invalid provider properly rejected"
    else
        echo "❌ Invalid provider not properly rejected"
        return 1
    fi
    
    echo "✅ Basic configuration loading tests passed"
    return 0
}

# Test core REPOCLI commands work
test_core_commands() {
    echo "🔧 Testing core REPOCLI commands..."
    
    # Test --repocli-version
    if repocli --repocli-version >/dev/null 2>&1; then
        echo "✅ --repocli-version command works"
    else
        echo "❌ --repocli-version command failed"
        return 1
    fi
    
    # Test --repocli-help
    if repocli --repocli-help >/dev/null 2>&1; then
        echo "✅ --repocli-help command works"
    else
        echo "❌ --repocli-help command failed"
        return 1
    fi
    
    echo "✅ Core commands tests passed"
    return 0
}

# Test repocli:init command
test_init_command() {
    echo "🔧 Testing repocli:init command..."
    
    # Create temporary directory for testing
    local temp_dir=$(mktemp -d)
    local original_pwd="$PWD"
    
    cd "$temp_dir"
    
    # Test that init doesn't crash (even without input)
    if echo "" | repocli repocli:init >/dev/null 2>&1; then
        echo "✅ repocli:init command runs without crashing"
    else
        echo "❌ repocli:init command crashed"
        cd "$original_pwd"
        rm -rf "$temp_dir"
        return 1
    fi
    
    cd "$original_pwd"
    rm -rf "$temp_dir"
    
    echo "✅ Init command tests passed"
    return 0
}

# Test basic provider functionality with valid configuration
test_provider_functionality() {
    echo "🔧 Testing basic provider functionality..."
    
    # Test GitHub provider with valid config
    local temp_config=$(mktemp)
    echo "provider=github" > "$temp_config"
    
    # Test that provider loads without crashing
    if REPOCLI_CONFIG="$temp_config" repocli --repocli-version >/dev/null 2>&1; then
        echo "✅ GitHub provider loads correctly"
    else
        echo "❌ GitHub provider failed to load"
        rm -f "$temp_config"
        return 1
    fi
    
    rm -f "$temp_config"
    
    # Test GitLab provider with valid config  
    local temp_config2=$(mktemp)
    echo "provider=gitlab" > "$temp_config2"
    echo "instance=https://gitlab.com" >> "$temp_config2"
    
    if REPOCLI_CONFIG="$temp_config2" repocli --repocli-version >/dev/null 2>&1; then
        echo "✅ GitLab provider loads correctly"
    else
        echo "❌ GitLab provider failed to load"
        rm -f "$temp_config2"
        return 1
    fi
    
    rm -f "$temp_config2"
    
    echo "✅ Provider functionality tests passed"
    return 0
}

# Test file path handling
test_file_path_handling() {
    echo "🔧 Testing file path handling..."
    
    # Test custom config file path
    local temp_config=$(mktemp)
    echo "provider=github" > "$temp_config"
    
    if repocli --repocli-config "$temp_config" --repocli-version >/dev/null 2>&1; then
        echo "✅ Custom config file path handling works"
    else
        echo "❌ Custom config file path handling failed"
        rm -f "$temp_config"
        return 1
    fi
    
    rm -f "$temp_config"
    
    echo "✅ File path handling tests passed"
    return 0
}

# Test error handling
test_error_handling() {
    echo "🔧 Testing error handling..."
    
    # Test missing config file
    if repocli --repocli-config "/nonexistent/config" --repocli-version >/dev/null 2>&1; then
        echo "❌ Missing config file should fail but didn't"
        return 1
    else
        echo "✅ Missing config file properly handled"
    fi
    
    # Test invalid config syntax (empty file)
    local empty_config=$(mktemp)
    if REPOCLI_CONFIG="$empty_config" repocli --repocli-version >/dev/null 2>&1; then
        echo "❌ Empty config file should fail but didn't"
        rm -f "$empty_config"
        return 1
    else
        echo "✅ Empty config file properly handled"
        rm -f "$empty_config"
    fi
    
    echo "✅ Error handling tests passed"
    return 0
}

# Run all backwards compatibility configuration tests
run_all_bc_config_tests() {
    echo "🧪 Running all backwards compatibility configuration tests"
    echo "========================================================="
    
    local failed_tests=0
    
    if ! test_core_commands; then
        ((failed_tests++))
        echo ""
    fi
    
    if ! test_basic_config_loading; then
        ((failed_tests++))
        echo ""
    fi
    
    if ! test_provider_functionality; then
        ((failed_tests++))
        echo ""
    fi
    
    if ! test_file_path_handling; then
        ((failed_tests++))
        echo ""
    fi
    
    if ! test_error_handling; then
        ((failed_tests++))
        echo ""
    fi
    
    if ! test_init_command; then
        ((failed_tests++))
        echo ""
    fi
    
    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All backwards compatibility tests PASSED"
        return 0
    else
        echo "❌ $failed_tests backwards compatibility tests FAILED"
        return 1
    fi
}