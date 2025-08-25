# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

REPOCLI is a universal command-line interface that provides GitHub CLI compatibility across multiple Git hosting providers (GitHub, GitLab, Gitea, Codeberg). It's written entirely in Bash and acts as a wrapper that translates GitHub CLI commands to provider-specific equivalents.

## Development Commands

### Building & Installation
```bash
# Standard build and install
make install

# User installation
make install-user

# Development setup
make dev-setup

# Create distribution tarball
make dist

# Test Homebrew formula
make homebrew-test
```

### Testing
```bash
# Run full test suite
make test
./tests/run-tests.sh

# Test specific providers
make test-github
make test-gitlab

# Syntax checking
make lint

# Development mode testing (run from source directory)
./repocli --help
./repocli --version
```

### Installation & Setup
```bash
# Install via Homebrew
brew install repocli

# Install locally for testing
./install.sh --user

# Test configuration
./repocli init

# Debug mode
export REPOCLI_DEBUG=1
./repocli auth status
```

### Configuration Testing
```bash
# Create test configurations
echo "provider=gitlab" > repocli.conf
echo "instance=https://gitlab.example.com" >> repocli.conf

# Test different providers
echo "provider=github" > test-github.conf
echo "provider=gitlab" > test-gitlab.conf
```

## Architecture

### Core Components

**Main Entry Point (`repocli`):**
- Handles command routing and library loading
- Detects installation location (Homebrew/system/user/development)
- Sources configuration and utility libraries
- Delegates to provider-specific wrappers
- Auto-detects Homebrew installations via Cellar path detection

**Configuration System (`lib/config.sh`):**
- Loads config from multiple locations in priority order:
  1. `./repocli.conf` (project-specific)
  2. `~/.repocli.conf` (user-specific) 
  3. `~/.config/repocli/config` (XDG compliant)
- Supports interactive initialization via `repocli init`
- Auto-detects CLI tools based on provider selection

**Provider Wrappers (`lib/providers/*.sh`):**
- Each provider implements `{provider}_execute()` function
- GitHub: Direct 1:1 passthrough to `gh`
- GitLab: Complex command translation to `glab` with parameter mapping
- Gitea/Codeberg: Placeholder implementations (not yet complete)

### Command Translation Architecture

The most complex part is the GitLab provider (`lib/providers/gitlab.sh`), which handles extensive command translation:

1. **Authentication commands**: Direct mapping (`gh auth` → `glab auth`)
2. **Issue commands**: Parameter translation (`--body-file` → `--description-file`)
3. **Comment commands**: Command mapping (`gh issue comment` → `glab issue note create`)
4. **JSON output**: Format conversion using `jq` transformations
5. **Instance support**: Uses `GITLAB_HOST` environment variable for custom instances

### Key Translation Patterns

**Parameter Mapping:**
- GitHub `--body-file` → GitLab `--description-file`
- GitHub `--json fields -q query` → GitLab `--output json | jq query`
- GitHub `gh issue comment` → GitLab `glab issue note create`

**Instance Handling:**
- Extracts hostname from full URLs (`https://gitlab.foo.com` → `gitlab.foo.com`)
- Sets `GITLAB_HOST` environment variable for glab CLI
- Only applies for non-gitlab.com instances

## Development Guidelines

### Adding New Providers

1. Create `lib/providers/newprovider.sh`
2. Implement `newprovider_execute()` function following the pattern:
   ```bash
   newprovider_execute() {
       debug_log "Provider executing: $*"
       
       if ! check_cli_tool "cli-tool"; then
           exit 1
       fi
       
       # Command translation logic here
       case "$cmd" in
           "auth") newprovider_auth_command "$@" ;;
           "issue") newprovider_issue_command "$@" ;;
           # etc.
       esac
   }
   ```
3. Add provider to `config.sh` CLI tool auto-detection
4. Add case in main `repocli` script
5. Update tests and documentation

### Extending GitLab Provider

The GitLab provider has the most sophisticated command mapping. Key functions:
- `gitlab_issue_view()`: Handles JSON field mapping and query translation
- `gitlab_issue_create()`: Parameter translation and output parsing
- `gitlab_issue_comment()`: Command name translation (note vs comment)

When adding new GitLab commands, follow the pattern of parsing gh-style arguments and converting to glab equivalents.

### Configuration Format

The configuration supports both simple and sectioned formats:

**Simple format:**
```ini
provider=gitlab
instance=https://gitlab.example.com
cli_tool=glab
```

**Sectioned format (from example):**
```ini
provider=gitlab

[gitlab]
instance=https://gitlab.example.com
```

### Testing Strategy

The test suite (`tests/run-tests.sh`) focuses on:
- Basic functionality (version, help)
- Configuration parsing and provider detection
- Library syntax validation
- Error handling scenarios
- Provider-specific command translation

Tests are designed to work without requiring actual CLI tool installation by checking error messages and behaviors.

### Debug and Error Handling

- Use `debug_log()` for debugging output (controlled by `REPOCLI_DEBUG`)
- Use `check_cli_tool()` to validate required CLI tools are available
- Provider functions should `exit 1` on errors, not return
- Error messages should be helpful and include installation instructions

### Custom GitLab Instance Support

GitLab provider automatically handles custom instances:
- Detects when `REPOCLI_INSTANCE` is set and non-gitlab.com
- Extracts hostname from full URL using sed
- Sets `GITLAB_HOST` environment variable for glab CLI
- All glab commands automatically use the custom instance

This approach works because glab CLI respects the `GITLAB_HOST` environment variable for all operations.