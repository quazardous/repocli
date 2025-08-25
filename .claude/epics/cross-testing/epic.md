---
name: cross-testing
status: in_progress
created: 2025-08-25T08:57:47Z
updated: 2025-08-25T12:13:57Z
last_sync: 2025-08-25T14:14:47Z
progress: 45%
prd: .claude/prds/cross-testing.md
github: https://github.com/quazardous/repocli/issues/1
---

# Epic: Cross-Testing

## Overview

Implement a cross-provider testing framework that validates REPOCLI command compatibility between GitHub CLI (`gh`) and GitLab CLI (`glab`). The system uses subdirectory isolation to test identical commands across providers, focusing on GitLab's complex parameter translation while leveraging GitHub's 1:1 passthrough as the baseline. Tests execute read-only operations on public repositories with JSON output comparison for semantic equivalence.

⚠️ **CRITICAL ISOLATION REQUIREMENT**: Tests must NEVER interfere with user's actual GitHub/GitLab authentication or configurations. All tests run in completely isolated environments using temporary configurations that are automatically cleaned up.

⚠️ **NO PROVIDER MIXING**: GitHub tests must ONLY use GitHub repositories, URLs, and terminology (e.g., github.com, gh CLI). GitLab tests must ONLY use GitLab repositories, URLs, and terminology (e.g., gitlab.com, glab CLI). Never mix provider-specific concepts in test data or implementations.

## Architecture Decisions

- **Subdirectory isolation** over Docker for simplicity and speed
- **Existing test framework extension** - integrate with `tests/run-tests.sh` rather than separate system
- **JSON semantic comparison** using `jq` for field mapping validation
- **Public repository approach** to avoid authentication complexity
- **Bash-based implementation** to match existing REPOCLI codebase patterns
- **Provider-specific test configuration** using temporary `repocli.conf` files

## Technical Approach

### Testing Framework Components

**Test Orchestration**
- Extend existing `tests/run-tests.sh` with cross-provider test suite
- Create isolated test environments in `tests/cross-testing/` subdirectories
- Manage temporary configurations without affecting user settings
- Execute tests in parallel where possible (different providers, different commands)

**Provider Configuration Management**
- Generate temporary `repocli.conf` files for each test scenario
- Support environment variable override for custom GitLab instances
- Clean up test configurations after execution
- Validate CLI tool availability before test execution
- ⚠️ **ISOLATION GUARANTEE**: Never modify user's `~/.gitconfig`, `~/.repocli.conf`, `~/.config/repocli/`, or any GitHub/GitLab authentication files

**Output Comparison Engine**
- JSON output normalization and comparison using `jq`
- Semantic equivalence validation (field presence, data type consistency)
- Error message pattern matching for failure scenarios
- Rate limit and network error handling

### Infrastructure

**Test Environment Structure**
```bash
tests/cross-testing/
├── run-cross-tests.sh           # Main test orchestrator
├── lib/                         # Shared test utilities
│   ├── test-isolation.sh        # Environment isolation functions
│   ├── output-comparison.sh     # JSON comparison utilities
│   └── provider-config.sh       # Configuration management
├── github-test/                 # GitHub provider test environment
│   └── repocli.conf            # provider=github
├── gitlab-test/                # GitLab.com test environment  
│   └── repocli.conf            # provider=gitlab, instance=https://gitlab.com
└── gitlab-custom-test/         # Custom GitLab instance test environment
    └── repocli.conf            # provider=gitlab, instance=$GITLAB_TEST_INSTANCE
```

**Integration Points**
- Hooks into existing `make test` command
- Uses existing REPOCLI library functions (`lib/config.sh`, `lib/providers/*.sh`)
- Leverages current debug logging system (`debug_log()`)
- Maintains compatibility with CI/CD pipeline structure

## Implementation Strategy

**Phase 1: Core Framework**
- Implement test isolation and configuration management
- Create basic command execution and output capture
- Add JSON comparison utilities using existing `jq` dependency

**Phase 2: Command Coverage**
- Implement issue listing and viewing tests
- Add authentication status validation
- Create error handling test scenarios

**Phase 3: Integration & Optimization**
- Integrate with existing test suite
- Add parallel execution capabilities
- Implement custom GitLab instance support

## Task Breakdown Preview

High-level task categories that will be created:
- [ ] **Test Framework Foundation**: Create test orchestration script and directory structure
- [ ] **Environment Isolation**: Implement configuration management and cleanup utilities  
- [ ] **JSON Output Comparison**: Build semantic equivalence validation using jq
- [ ] **Test Configuration Setup**: Implement `/tests:init` command for interactive GitLab repository setup
- [ ] **GitHub Provider Tests**: Minimal validation tests for 1:1 passthrough
- [ ] **GitLab Provider Tests**: Comprehensive parameter translation and command mapping tests
- [ ] **Error Handling Tests**: Network failures, invalid repos, rate limiting scenarios
- [ ] **Integration with Existing Test Suite**: Extend `make test` and `tests/run-tests.sh`
- [ ] **Custom GitLab Instance Support**: Environment variable configuration and validation
- [ ] **Performance Optimization**: Parallel execution and test suite timing optimization

## Dependencies

**External Dependencies**
- GitHub CLI (`gh`) - already required by REPOCLI
- GitLab CLI (`glab`) - already required by REPOCLI
- `jq` tool for JSON processing - already used in GitLab provider
- Public test repositories: `microsoft/vscode` (GitHub)
- **GitLab Test Repository**: User-provided via `.tests.conf` (private repository for comprehensive GitLab testing)

**Internal Dependencies**
- Existing configuration system (`lib/config.sh`)
- GitLab provider implementation (`lib/providers/gitlab.sh`)
- Current test framework (`tests/run-tests.sh`)
- Debug logging utilities

**Environment Dependencies**
- Internet connectivity for API access
- No authentication tokens required for basic GitHub tests (read-only public repos)
- **GitLab Testing Configuration**: Local `.tests.conf` file for private GitLab repository access
- Optional: Custom GitLab instance URL via `GITLAB_TEST_INSTANCE` environment variable

**GitLab Test Configuration (`.tests.conf`)**
```ini
# GitLab test repository (private, user-provided)
gitlab_test_repo=your-username/your-test-repo
gitlab_test_instance=https://gitlab.com  # or your custom instance

# Optional: specific issue numbers for testing
gitlab_test_issue=123
gitlab_test_user=your-username
```

⚠️ **SECURITY**: The `.tests.conf` file must be excluded from version control (added to `.gitignore`) as it contains references to private repositories. A `.tests.conf.example` template file will be versioned for user guidance.

**Interactive Test Configuration (`/tests:init`)**
A dedicated command will handle test configuration setup:
```bash
/tests:init
```

This command will:
1. Check if `.tests.conf` already exists (warn before overwriting)
2. Interactively prompt for:
   - GitLab instance URL (default: https://gitlab.com)
   - Private GitLab repository (format: username/repository)
   - Optional test issue number for validation
   - Optional test username
3. Validate repository access (test read permissions)
4. Create `.tests.conf` with proper format
5. Update `.gitignore` to exclude `.tests.conf` if not already present

## Success Criteria (Technical)

**Performance Benchmarks**
- Full test suite completion under 2 minutes
- Individual command tests under 10 seconds
- Parallel execution reduces total time by 50%

**Quality Gates**
- 100% test coverage of core commands (issue list, issue view, auth status)
- Zero false positives in JSON output comparison
- All GitLab parameter translations validated against GitHub baseline
- Error handling covers network failures, invalid repos, rate limits

**Acceptance Criteria**
- Integration with `make test` command
- CI/CD pipeline compatibility maintained
- Custom GitLab instance configuration working
- Test reliability > 95% on repeated runs

## Tasks Created  
- [ ] #10 - Performance Optimization and Parallel Execution (parallel: false)
- [ ] #14 - Implement Test Configuration Setup Command (depends on #17, #18) (parallel: true)
- [x] #17 - Add --repocli-config option and REPOCLI_CONFIG environment variable support (parallel: false) ✅ COMPLETED
- [x] #18 - Fix wrapper option conflicts - avoid shadowing wrapped CLI commands (parallel: false) ✅ COMPLETED
- [x] #2 - Create Test Framework Foundation (parallel: true) ✅ COMPLETED
- [x] #3 - Implement Environment Isolation Utilities (parallel: false) ✅ COMPLETED
- [x] #4 - Build JSON Output Comparison Engine (parallel: true) ✅ COMPLETED
- [ ] #5 - Implement GitHub Provider Tests (depends on #18) (parallel: true)
- [ ] #6 - Implement GitLab Provider Tests (depends on #18) (parallel: false)
- [ ] #7 - Implement Error Handling and Edge Case Tests (depends on #18) (parallel: true)
- [ ] #8 - Integrate with Existing Test Suite (depends on #18) (parallel: false)
- [ ] #9 - Add Custom GitLab Instance Support (depends on #18) (parallel: true)
- [ ] #19 - Add support for tags/labels in issue creation and listing commands (depends on #18) (parallel: true)
- [ ] #20 - Add support for parent/child issue relationships (depends on #18) (parallel: true)
- [ ] #21 - Add comprehensive tests for issue close/reopen operations (depends on #18) (parallel: true)
- [ ] #22 - Add comprehensive coverage of GitHub CLI features used by PM system (depends on #18) (parallel: true)
- [ ] #23 - Add extension command framework and sub-issue simulation (depends on #22) (parallel: false)
- [ ] #24 - Enhance JSON query support for complex -q patterns (depends on #22) (parallel: true)
- [ ] #25 - Add assignee and label management for issue editing (depends on #22) (parallel: true)
- [ ] #26 - Standardize provider documentation with source of truth approach (depends on []) (parallel: true)

Total tasks: 18
Completed tasks: 5
Parallel tasks: 13
Sequential tasks: 5
## Estimated Effort

**Overall Timeline**: 3-5 days implementation
**Critical Path**: Test isolation framework → Command testing → Integration

**Resource Requirements**
- Single developer with bash scripting experience
- Access to public GitHub and GitLab repositories
- Optional: Custom GitLab instance for comprehensive testing

**Effort Breakdown**
- Framework foundation: 1 day
- Command testing implementation: 2 days  
- Integration and optimization: 1-2 days
- Documentation and cleanup: 0.5 day
