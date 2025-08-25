# Test Mode Handler

Framework logic for handling different GitLab test modes based on user configuration.

## Test Mode Configurations

### 1. Hybrid Mode (Default)
- **Description**: Use existing issues if available, create temporary ones if needed
- **Behavior**: 
  - Try to list existing issues first
  - If issues available, use the first one for testing
  - If no issues, create temporary test issue
  - Clean up temporary issues after tests
- **Best for**: Most users - balances safety and comprehensive testing

### 2. Read-Only Mode
- **Description**: Only use read operations (safest, limited testing)
- **Behavior**:
  - Only test `issue list`, `repo info`, `auth status`
  - Never create, modify, or delete issues
  - Skip tests that require specific issue numbers
- **Best for**: Production repositories, strict environments

### 3. Auto-Create Mode  
- **Description**: Always create temporary test issues (most comprehensive)
- **Behavior**:
  - Always create fresh test issues for each test run
  - Clean up all created issues after tests
  - Most comprehensive testing possible
- **Best for**: Dedicated test repositories, full validation

### 4. Existing-Only Mode
- **Description**: Only test with existing issues (fail if none available)
- **Behavior**:
  - Require at least one existing issue
  - Use first available issue for testing
  - Fail tests if repository is empty
- **Best for**: Repositories with guaranteed existing issues

## Implementation Logic

```bash
# Function: get_test_issue()
# Returns issue number to use for testing based on mode
get_test_issue() {
    local mode="${gitlab_test_mode:-hybrid}"
    local repo="$gitlab_test_repo"
    local prefix="${gitlab_test_prefix:-[REPOCLI-TEST]}"
    
    case "$mode" in
        "read_only")
            echo "SKIP"  # Skip issue-specific tests
            return 0
            ;;
            
        "existing_only")
            # Get first existing issue
            local issue=$(glab issue list --repo "$repo" --per-page 1 --output json | jq -r '.[0].iid // empty')
            if [[ -z "$issue" ]]; then
                echo "ERROR: No existing issues found in $repo" >&2
                return 1
            fi
            echo "$issue"
            ;;
            
        "auto_create")
            # Always create new issue
            local title="$prefix Auto-created test issue $(date +%s)"
            local description="Temporary issue created by REPOCLI cross-testing framework. Safe to delete after tests complete."
            local issue=$(glab issue create --title "$title" --description "$description" --repo "$repo" | grep -oE '[0-9]+$')
            echo "$issue"
            ;;
            
        "hybrid"|*)
            # Try existing first, fallback to creation
            local issue=$(glab issue list --repo "$repo" --per-page 1 --output json 2>/dev/null | jq -r '.[0].iid // empty')
            if [[ -n "$issue" ]]; then
                echo "$issue"
            else
                # Create temporary issue
                local title="$prefix Hybrid mode test issue $(date +%s)"
                local description="Temporary issue created by REPOCLI cross-testing framework. Safe to delete after tests complete."
                local issue=$(glab issue create --title "$title" --description "$description" --repo "$repo" | grep -oE '[0-9]+$')
                echo "$issue"
            fi
            ;;
    esac
}

# Function: cleanup_test_issues()
# Clean up temporary issues created during testing
cleanup_test_issues() {
    local mode="${gitlab_test_mode:-hybrid}"
    local repo="$gitlab_test_repo"
    local prefix="${gitlab_test_prefix:-[REPOCLI-TEST]}"
    
    case "$mode" in
        "read_only"|"existing_only")
            # No cleanup needed
            return 0
            ;;
            
        "auto_create"|"hybrid")
            # Find and close temporary issues
            local temp_issues=$(glab issue list --repo "$repo" --search "$prefix" --output json | jq -r '.[].iid')
            for issue in $temp_issues; do
                if [[ -n "$issue" ]]; then
                    glab issue close "$issue" --repo "$repo" >/dev/null 2>&1
                    echo "Cleaned up temporary issue #$issue"
                fi
            done
            ;;
    esac
}

# Function: should_skip_issue_tests()
# Determine if issue-specific tests should be skipped
should_skip_issue_tests() {
    local mode="${gitlab_test_mode:-hybrid}"
    [[ "$mode" == "read_only" ]] && return 0
    return 1
}
```

## Usage in Tests

```bash
#!/bin/bash
# Example GitLab provider test

source .tests.conf
source tests/cross-testing/lib/test-mode-handler.sh

# Get issue for testing (or SKIP)
test_issue=$(get_test_issue)
if [[ "$test_issue" == "SKIP" ]]; then
    echo "Skipping issue-specific tests (read-only mode)"
    exit 0
elif [[ "$test_issue" == "ERROR"* ]]; then
    echo "$test_issue"
    exit 1
fi

# Run tests with the issue
echo "Testing with issue #$test_issue"
glab issue view "$test_issue" --repo "$gitlab_test_repo"

# Cleanup at the end
cleanup_test_issues
```

## Security Considerations

- Temporary issues are clearly marked with prefix
- Cleanup always runs, even on test failure (trap handlers)
- Read-only mode ensures no modifications to user's repository
- User has full control over test behavior via mode selection

## Error Handling

- Network failures during issue creation
- Permission issues (create vs read permissions)
- Repository access problems
- Cleanup failures (warn but don't fail tests)