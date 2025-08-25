---
name: cross-testing
description: Cross-provider testing framework for REPOCLI command compatibility between GitHub CLI and GitLab CLI
status: backlog
created: 2025-08-25T08:52:09Z
---

# PRD: Cross-Testing

## Executive Summary

Cross-testing is a comprehensive testing framework for REPOCLI that validates command compatibility and translation accuracy between GitHub CLI (`gh`) and GitLab CLI (`glab`). The system will ensure REPOCLI's provider abstraction works correctly across different Git hosting providers, with focus on read-only operations using public repositories and configurable test environments.

## Problem Statement

**What problem are we solving?**
- REPOCLI acts as a universal wrapper around different Git hosting CLI tools, but lacks systematic validation that commands work consistently across providers
- Complex GitLab command translation (parameter mapping, JSON output transformation) needs verification against GitHub's baseline behavior
- No automated way to catch regressions when GitLab provider translation logic changes
- Developers cannot confidently validate that new GitLab command mappings work correctly

**Why is this important now?**
- GitLab provider has sophisticated command translation that can easily break
- Adding new providers requires confidence in the existing translation framework
- Manual testing across providers is time-consuming and error-prone
- Public deployment needs assurance that core commands work across all supported providers

## User Stories

**Primary Persona: REPOCLI Developer**
- As a developer, I want to run cross-provider tests to validate my changes don't break command translation
- As a developer, I want to add new GitLab command mappings with confidence they match GitHub behavior
- As a developer, I want isolated test environments that don't interfere with my personal CLI configurations

**Secondary Persona: CI/CD Pipeline**
- As a CI system, I want to automatically validate cross-provider compatibility on every commit
- As a CI system, I want fast, reliable tests that don't depend on external authentication or write permissions

## Requirements

### Functional Requirements

**Core Testing Framework**
- Execute identical commands against both `gh` and `glab` providers
- Compare outputs for consistency (JSON structure, field mapping, error messages)
- Test command translation accuracy for GitLab provider
- Support both public repositories and configurable private test repositories

**Test Isolation**
- Isolated test environments using subdirectories (not Docker initially)
- Separate REPOCLI configuration files per test scenario
- No interference with user's existing CLI tool configurations
- Temporary configuration management during test execution

**Provider-Specific Testing**
- **GitHub (`gh`)**: Minimal testing since it's 1:1 passthrough - validate basic connectivity and JSON output
- **GitLab (`glab`)**: Comprehensive testing of parameter translation, command mapping, and JSON transformation
- **Custom GitLab instances**: Support for user-provided test repository configuration

**Test Scenarios**
- Issue listing: `repocli issue list` across providers
- Issue viewing: `repocli issue view <number>` with JSON output comparison
- Authentication status: `repocli auth status` 
- Repository information: Basic repo metadata retrieval
- Error handling: Invalid commands, missing repositories, network failures

### Non-Functional Requirements

**Performance**
- Test suite completion under 2 minutes for full cross-provider validation
- Parallel execution where possible (different providers, different commands)
- Minimal API calls - focus on read-only operations

**Security**
- No storage of authentication tokens in test files
- Support for environment-variable based authentication
- Clear separation between test data and production configurations

**Reliability**
- Tests must work without write permissions to repositories
- Graceful handling of API rate limits
- Network failure resilience with meaningful error messages

## Success Criteria

**Measurable Outcomes**
- 100% of core commands tested across GitHub and GitLab.com
- Cross-provider JSON output consistency validated (same fields, compatible values)
- Zero false positives - tests only fail on actual compatibility issues
- Custom GitLab instance configuration working with user-provided test repositories

**Key Metrics**
- Command compatibility score: % of commands producing equivalent results
- Test execution time: < 2 minutes for full suite
- Test reliability: > 95% success rate on repeated runs
- Coverage: All GitLab parameter translations validated

## Constraints & Assumptions

**Technical Limitations**
- Public repositories only for default testing (no write operations)
- Rate limiting on public Git hosting APIs
- Dependency on external CLI tools (`gh`, `glab`) being installed
- Network connectivity required for API-based tests

**Implementation Constraints**
- Use subdirectory isolation instead of Docker for simplicity
- Focus on read-only operations to avoid authentication complexity
- Test data must not depend on specific repository state (issues, commits)

**Timeline Constraints**
- Initial implementation should handle GitHub.com and GitLab.com
- Custom GitLab instance support can be phase 2
- Full integration with existing test suite (`tests/run-tests.sh`)

## Out of Scope

**Explicitly NOT building**
- Write operations testing (issue creation, PR creation)
- Authentication flow testing across providers
- Performance benchmarking between providers
- Full Docker-based isolation (keeping it simple with subdirectories)
- Gitea/Codeberg provider testing (placeholder implementations not ready)
- Real-time monitoring or alerting for cross-provider compatibility

## Dependencies

**External Dependencies**
- GitHub CLI (`gh`) installed and functional
- GitLab CLI (`glab`) installed and functional
- Internet connectivity for API access
- Public test repositories (suggest: `octocat/Hello-World` for GitHub, `gitlab-examples/sample-project` for GitLab)

**Internal Dependencies**
- Existing REPOCLI configuration system (`lib/config.sh`)
- GitLab provider translation logic (`lib/providers/gitlab.sh`)
- Current test framework structure (`tests/run-tests.sh`)

**Test Environment Setup**
- For custom GitLab instances: User must provide test repository URL and access configuration
- Temporary configuration management during test isolation
- Clean-up procedures for test-generated configuration files

## Technical Implementation Notes

**Test Isolation Strategy**
```bash
# Create isolated test environments in subdirectories:
tests/cross-testing/
├── github-test/           # GitHub provider test environment
│   └── repocli.conf      # provider=github
├── gitlab-test/          # GitLab.com test environment  
│   └── repocli.conf      # provider=gitlab, instance=https://gitlab.com
└── gitlab-custom-test/   # Custom GitLab instance test environment
    └── repocli.conf      # provider=gitlab, instance=user-provided
```

**Command Comparison Strategy**
- Execute same logical command through REPOCLI with different provider configs
- Parse and normalize JSON outputs for comparison
- Focus on semantic equivalence rather than exact string matching
- Use `jq` for JSON field validation and transformation verification

**Recommended Public Test Repositories**
- GitHub: `microsoft/vscode` (large, active, stable issue history)
- GitLab.com: `gitlab-org/gitlab` (official project with consistent structure)
- Custom GitLab: User-configurable via environment variables