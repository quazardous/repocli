# Development Guide

This guide covers development practices, architecture decisions, and implementation details for REPOCLI contributors.

## Architecture Overview

REPOCLI follows a modular architecture with clear separation of concerns:

```
repocli (main) -> config.sh -> provider.sh -> native CLI -> hosting platform
```

### Key Components

1. **Main CLI (`repocli`)** - Entry point, handles routing and library loading
2. **Configuration System (`lib/config.sh`)** - Config file parsing and management  
3. **Utilities (`lib/utils.sh`)** - Shared helper functions
4. **Provider Wrappers (`lib/providers/`)** - CLI-specific command translation
5. **Test Suite (`tests/`)** - Comprehensive testing framework

## Provider Implementation

### Provider Interface

Each provider must implement:

```bash
{provider}_execute() {
    # 1. Validate CLI tool availability
    # 2. Handle configuration (instance URLs, etc.)
    # 3. Route commands to appropriate handlers
    # 4. Translate parameters and options
    # 5. Execute native CLI commands
}
```

### Command Translation Patterns

#### 1. Direct Passthrough (GitHub)
```bash
github_execute() {
    exec gh "$@"  # Simple 1:1 mapping
}
```

#### 2. Parameter Translation (GitLab)
```bash
# GitHub: --body-file
# GitLab:  --description-file
if [[ -n "$body_file" ]]; then
    glab_cmd="$glab_cmd --description-file \"$body_file\""
fi
```

#### 3. Command Mapping (GitLab Comments)
```bash
# GitHub: gh issue comment 123 --body-file comment.md
# GitLab:  glab issue note create 123 --message "$(cat comment.md)"
gitlab_issue_comment() {
    glab issue note create "$issue_num" --message "$(cat "$body_file")"
}
```

#### 4. JSON Output Transformation
```bash
# Map GitHub CLI JSON fields to provider equivalents
case "$json_fields" in
    "body") glab issue view "$issue_num" --output json | jq -r '.description' ;;
    "number") echo "$issue_num" ;;
esac
```

### Instance Configuration

For providers supporting custom instances:

```bash
# Extract hostname and set environment variable
if [[ -n "$REPOCLI_INSTANCE" ]]; then
    hostname=$(echo "$REPOCLI_INSTANCE" | sed 's|^https\?://||' | sed 's|/.*$||')
    export GITLAB_HOST="$hostname"  # glab uses this automatically
fi
```

## Testing Strategy

### Test Categories

1. **Unit Tests** - Individual function testing
2. **Integration Tests** - Provider command translation  
3. **System Tests** - End-to-end installation and usage
4. **Syntax Tests** - Shell script validation

### Test Organization

```
tests/
├── run-tests.sh        # Main test runner
├── test-github.sh      # GitHub provider tests  
├── test-gitlab.sh      # GitLab provider tests
└── test-providers.sh   # Cross-provider tests
```

### Mock Testing

Tests are designed to work without actual CLI tools installed:

```bash
# Test provider detection by examining error messages
if $REPOCLI_BIN auth status 2>&1 | grep -E "github|not found|CLI tool.*not found"; then
    test_pass "Provider detection works"
fi
```

## Configuration System

### Configuration Hierarchy

1. `./repocli.conf` (project-specific, highest priority)
2. `~/.repocli.conf` (user-specific)  
3. `~/.config/repocli/config` (XDG compliant, lowest priority)

### Configuration Format

**Simple Format:**
```ini
provider=gitlab
instance=https://gitlab.example.com
cli_tool=glab
```

**Sectioned Format (future):**
```ini
provider=gitlab

[gitlab]
instance=https://gitlab.example.com

[github]  
# GitHub-specific settings
```

## Build System

### Makefile Targets

- `make install` - Install to system (/usr/local)
- `make install-user` - Install to user (~/.local)  
- `make test` - Run test suite
- `make lint` - Shell script linting
- `make dist` - Create distribution tarball
- `make homebrew-test` - Test Homebrew formula

### Distribution

```bash
# Create release tarball
make dist

# Results in: repocli-1.0.0.tar.gz
# Contains: repocli, lib/, tests/, docs/, Formula/
```

## Error Handling

### Patterns

1. **CLI Tool Validation**
```bash
if ! check_cli_tool "glab"; then
    exit 1  # check_cli_tool prints helpful error
fi
```

2. **Configuration Errors**
```bash
if [[ -z "$REPOCLI_PROVIDER" ]]; then
    echo "❌ REPOCLI not configured" >&2
    echo "Run: repocli init" >&2
    exit 1
fi
```

3. **Command Translation Errors**
```bash
case "$cmd" in
    "supported-command") handle_command "$@" ;;
    *) 
        echo "Error: Unsupported command '$cmd'" >&2
        echo "Supported: auth, issue, repo" >&2
        exit 1
        ;;
esac
```

## Debugging

### Debug Mode

```bash
export REPOCLI_DEBUG=1
repocli issue view 123
# [DEBUG] GitLab provider executing: issue view 123
# [DEBUG] Using GitLab instance: gitlab.example.com
```

### Implementation

```bash
debug_log() {
    if [[ "${REPOCLI_DEBUG:-}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}
```

## Release Process

### Version Management

1. Update `VERSION` file
2. Update version in `repocli` script  
3. Update `CHANGELOG.md`
4. Update Homebrew formula SHA256

### Release Checklist

- [ ] All tests pass (`make test`)
- [ ] Shell scripts pass linting (`make lint`)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped consistently
- [ ] Homebrew formula tested (`make homebrew-test`)
- [ ] GitHub release created
- [ ] Distribution tarball attached

### GitHub Actions

- **CI Pipeline** - Tests on multiple OS/bash versions
- **Release Pipeline** - Automated release creation and asset upload
- **Homebrew Integration** - Formula validation and update

## Performance Considerations

### CLI Tool Detection

Cache CLI tool availability to avoid repeated `command -v` calls:

```bash
# In provider initialization
if ! check_cli_tool "glab"; then
    exit 1  # Exit early if tool unavailable
fi
```

### Configuration Loading

Load configuration once at startup, not per command.

### Command Execution

Use `exec` for simple passthrough to avoid extra process:

```bash
exec gh "$@"  # GitHub provider
```

Use subshells sparingly to avoid performance overhead.

## Security Considerations

### Input Validation

- Quote all variables: `"$variable"`
- Validate URLs: `validate_url "$instance"`  
- Sanitize file paths
- Avoid `eval` where possible

### Configuration Files

- Never log sensitive configuration
- Validate configuration file permissions
- Handle missing/malformed config gracefully

### CLI Tool Execution

- Use full command paths when possible
- Validate arguments passed to native CLI tools
- Handle CLI tool output securely

## Future Enhancements

### Plugin System

Potential architecture for extensible providers:

```
lib/
├── core/           # Core functionality
├── providers/      # Built-in providers  
└── plugins/        # User-installed providers
```

### Shell Completions

Framework for generating completions:

```bash
# Generate bash completion
repocli completion bash > /etc/bash_completion.d/repocli

# Support for:
# - Command completion
# - Provider-specific options
# - Dynamic completion (issue numbers, etc.)
```

### Advanced Configuration

Enhanced configuration with inheritance and profiles:

```ini
[default]
debug=false

[profiles.work]
provider=gitlab
instance=https://gitlab.company.com

[profiles.personal]  
provider=github
```

This development guide should be updated as the project evolves and new patterns emerge.