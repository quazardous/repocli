# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Project management structure
- Homebrew formula and support
- Enhanced path detection for Homebrew installations
- Makefile with standard build targets
- GitLab custom instance support via GITLAB_HOST

### Changed
- Updated README with Homebrew installation instructions
- Enhanced CLAUDE.md with build process documentation
- Improved install script with Homebrew detection

## [1.0.0] - 2024-01-XX (Planned)
### Added
- Universal CLI interface for GitHub, GitLab, Gitea, Codeberg
- GitHub CLI compatibility layer
- Configuration management system
- Interactive configuration setup (`repocli init`)
- Provider-specific command wrappers
- GitHub provider (1:1 passthrough to gh)
- GitLab provider with comprehensive command translation
- Gitea provider (placeholder implementation)
- Codeberg provider (placeholder implementation)
- Installation script with system/user options
- Comprehensive test suite
- Shell script linting and validation
- Documentation (README, CLAUDE.md)

### GitHub Provider
- Direct passthrough to `gh` CLI
- All GitHub CLI commands supported natively

### GitLab Provider
- Authentication commands (`auth status`, `auth login`)
- Issue management (`issue list`, `issue view`, `issue create`, `issue edit`, `issue comment`, `issue close`, `issue reopen`)
- Repository operations (`repo view`)
- Parameter translation (--body-file → --description-file)
- JSON output conversion with jq
- Comment command mapping (issue comment → issue note create)
- Custom GitLab instance support

### Configuration
- Multiple configuration file locations
- Interactive setup wizard
- Provider auto-detection of CLI tools
- Instance URL support for self-hosted providers

### Installation
- System-wide installation (/usr/local)
- User installation (~/.local)
- Homebrew support
- Automatic PATH configuration
- Uninstall capability

### Testing
- Unit tests for all components
- Provider-specific test suites
- Shell syntax validation
- Error handling verification
- Configuration parsing tests

## [0.1.0] - 2024-01-XX (Initial Development)
### Added
- Initial project structure
- Basic CLI framework
- Configuration system foundation
- GitHub provider skeleton
- GitLab provider skeleton