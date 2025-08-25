# Contributing to REPOCLI

Thank you for your interest in contributing to REPOCLI! This document provides guidelines and information for contributors.

## Code of Conduct
Be respectful, inclusive, and constructive in all interactions.

## How to Contribute

### Reporting Issues
- Use GitHub Issues for bug reports and feature requests
- Check existing issues before creating new ones
- Provide detailed information including:
  - Operating system and version
  - Shell type and version
  - REPOCLI version
  - Steps to reproduce
  - Expected vs actual behavior

### Feature Requests
- Use GitHub Issues with the "enhancement" label
- Describe the use case and expected behavior
- Consider if it aligns with the project goals

### Pull Requests
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Run the test suite (`make test`)
6. Run linting (`make lint`)
7. Update documentation as needed
8. Commit your changes (`git commit -m 'Add amazing feature'`)
9. Push to your branch (`git push origin feature/amazing-feature`)
10. Create a Pull Request

## Development Setup

### Prerequisites
- Bash 4.0+
- jq (for JSON processing)
- make (for build tasks)
- shellcheck (for linting, optional but recommended)

### Setup
```bash
git clone https://github.com/quazardous/repocli.git
cd repocli
make dev-setup
./repocli --help
```

### Testing
```bash
# Run all tests
make test

# Test specific components
make test-github
make test-gitlab

# Check shell syntax
make lint
```

## Coding Standards

### Shell Scripting
- Use bash shebang: `#!/bin/bash`
- Enable strict mode: `set -euo pipefail`
- Quote variables: `"$variable"`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Function names use snake_case
- Global variables use UPPER_CASE
- Local variables use lower_case

### File Organization
- Main executable: `repocli`
- Libraries: `lib/*.sh`
- Providers: `lib/providers/{provider}.sh`
- Tests: `tests/test-*.sh`
- Documentation: `*.md`

### Provider Implementation
Each provider must implement a `{provider}_execute()` function:

```bash
provider_execute() {
    debug_log "Provider executing: $*"
    
    # Check CLI tool availability
    if ! check_cli_tool "cli-tool"; then
        exit 1
    fi
    
    # Command routing
    local cmd="$1"
    shift
    
    case "$cmd" in
        "auth") provider_auth_command "$@" ;;
        "issue") provider_issue_command "$@" ;;
        "repo") provider_repo_command "$@" ;;
        *) echo "Unsupported command: $cmd" >&2; exit 1 ;;
    esac
}
```

### Command Translation
When translating GitHub CLI commands to other providers:

1. **Preserve GitHub CLI compatibility** - Commands should work identically
2. **Handle parameter mapping** - Translate flags and options appropriately
3. **Maintain output format** - JSON outputs should be consistent
4. **Provide helpful errors** - Clear messages when features aren't supported

Example GitLab translation:
```bash
# GitHub: gh issue comment 123 --body-file comment.md
# GitLab: glab issue note create 123 --message "$(cat comment.md)"
```

## Testing Guidelines

### Test Structure
- Test basic functionality (help, version)
- Test configuration loading
- Test provider detection
- Test error handling
- Test command translation (where applicable)

### Provider Tests
Each provider should have tests for:
- CLI tool detection
- Authentication commands
- Issue management
- Repository operations
- Error scenarios

### Integration Tests
- Test with actual CLI tools (when available)
- Test configuration scenarios
- Test installation methods

## Documentation

### User Documentation
- Keep README.md up-to-date
- Document new features and changes
- Provide usage examples
- Update installation instructions

### Developer Documentation
- Update CLAUDE.md for architectural changes
- Document new provider patterns
- Update this CONTRIBUTING.md as needed

### Code Documentation
- Use clear function names
- Add comments for complex logic
- Document provider-specific quirks
- Include usage examples in comments

## Release Process

### Version Numbering
- Follow Semantic Versioning (semver.org)
- MAJOR: Breaking changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible

### Pre-release Checklist
- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in relevant files
- [ ] Homebrew formula updated (if needed)

### Release Steps
1. Create release branch
2. Update version numbers
3. Update CHANGELOG.md
4. Test installation methods
5. Create GitHub release
6. Update Homebrew formula
7. Announce release

## Provider-Specific Guidelines

### GitHub Provider
- Should be a simple passthrough to `gh`
- No command translation needed
- Focus on error handling and availability

### GitLab Provider
- Complex command translation required
- Handle instance configuration
- Map JSON outputs appropriately
- Support custom GitLab instances

### Gitea/Codeberg Providers
- Use `tea` CLI
- Handle instance configuration
- Map commands from GitHub CLI format
- Consider tea-specific features

## Getting Help

- Create an issue for questions
- Check existing documentation
- Review similar provider implementations
- Ask in GitHub Discussions

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes (for significant contributions)
- README.md acknowledgments

Thank you for contributing to REPOCLI!