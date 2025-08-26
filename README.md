# REPOCLI - Universal Git Hosting Provider CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**REPOCLI** is a universal command-line interface that provides GitHub CLI compatibility across multiple Git hosting providers. Write commands once, run them anywhere.

## 🎯 Wrapper Principle

REPOCLI acts as a **transparent wrapper** around existing CLI tools:
- **Passes through** standard commands to the underlying CLI (gh, glab, tea)
- **Only intercepts** wrapper-specific options (prefixed with `--repocli-` or `repocli:`)
- **Maintains compatibility** with existing CLI tool workflows

```bash
# These pass through to the underlying CLI tool
repocli --help              # → gh help, glab help, or tea help
repocli --version           # → gh version, glab version, or tea version  
repocli init my-repo        # → gh init my-repo, glab init, etc.

# These are wrapper-specific
repocli --repocli-help      # → Show wrapper help
repocli --repocli-version   # → Show wrapper version
repocli repocli:init        # → Configure wrapper
```

## 🚀 Features

- **Universal Interface**: Single command syntax across all providers
- **GitHub CLI Compatible**: Drop-in replacement for `gh` commands
- **Zero Dependencies**: Pure bash, no Node.js, Python, or external packages
- **Multiple Providers**: GitHub, GitLab, Gitea, Codeberg support
- **Easy Installation**: Simple curl/bash installation
- **Flexible Configuration**: Project-specific or global configuration

## 🏗 Supported Providers

| Provider | CLI Tool | Status | Auth Command |
|----------|----------|--------|--------------|
| **GitHub** | `gh` | ✅ Full | `gh auth login` |
| **GitLab** | `glab` | ✅ Full | `glab auth login` |
| **Gitea** | `tea` | ❌ Planned | `tea login add` |
| **Codeberg** | `tea` | ❌ Planned | `tea login add` |

## 📦 Installation

### Homebrew (Recommended for macOS/Linux)
```bash
brew install repocli
```

### Quick Install Script
```bash
curl -fsSL https://raw.githubusercontent.com/quazardous/repocli/main/install.sh | bash
```

### User Installation
```bash
curl -fsSL https://raw.githubusercontent.com/quazardous/repocli/main/install.sh | bash -s -- --user
```

### Manual Installation
```bash
git clone https://github.com/quazardous/repocli.git
cd repocli
make install  # or sudo make install for system-wide
```

### Development Installation
```bash
git clone https://github.com/quazardous/repocli.git
cd repocli
make dev-setup
./repocli --repocli-help
```

### Verify Installation
```bash
repocli --repocli-version    # Show wrapper version
repocli --repocli-help       # Show wrapper help
repocli --version            # Show underlying CLI version (gh/glab/tea)
repocli --help               # Show underlying CLI help (gh/glab/tea)
```

## ⚙️ Configuration

### Initialize Configuration
```bash
repocli repocli:init
```

This will prompt you to:
1. Select your Git hosting provider
2. Configure provider-specific settings
3. Choose configuration location (project vs global)

### Configuration Files

REPOCLI looks for configuration in this order:
1. `./repocli.conf` (project-specific)
2. `~/.repocli.conf` (user-specific)
3. `~/.config/repocli/config` (XDG compliant)

### Example Configuration
```ini
# REPOCLI Configuration
provider=gitlab
instance=https://gitlab.example.com

# Override auto-detected CLI tool (optional)
#cli_tool=glab
```

## 🔧 Usage

### Authentication
```bash
# Check authentication status (any provider)
repocli auth status

# Login (provider-specific)
repocli auth login  # Redirects to: gh/glab/tea auth login
```

### Issue Management
```bash
# List issues
repocli issue list

# View issue details
repocli issue view 123

# Create issue
repocli issue create --title "Bug fix" --body-file description.md

# Add comment
repocli issue comment 123 --body-file comment.md

# Close issue
repocli issue close 123 --comment "Fixed in v1.2"
```

### Repository Operations
```bash
# View repository info
repocli repo view

# Get repository name (for scripts)
repocli repo view --json nameWithOwner -q .nameWithOwner
```

### GitHub CLI Compatibility
All commands are designed to be drop-in replacements for GitHub CLI:
```bash
# Instead of: gh issue list
repocli issue list

# Instead of: gh issue view 123 --json body -q .body
repocli issue view 123 --json body -q .body

# Instead of: gh auth status
repocli auth status
```


## 🧪 Command Mapping

### GitHub → GitLab Examples

| GitHub Command | GitLab Equivalent | REPOCLI |
|----------------|-------------------|---------|
| `gh issue view 123` | `glab issue view 123` | `repocli issue view 123` |
| `gh issue create --title "Bug"` | `glab issue create --title "Bug"` | `repocli issue create --title "Bug"` |
| `gh issue comment 123 --body "Fix"` | `glab issue note create 123 --message "Fix"` | `repocli issue comment 123 --body-file -` |
| `gh auth status` | `glab auth status` | `repocli auth status` |

### Parameter Translation
- `--body-file` → `--description-file` (GitLab)
- `--json fields` → `--output json | jq` (GitLab)
- `gh issue comment` → `glab issue note create` (GitLab)
- Error handling for unsupported features

## 🧩 Architecture

```
User Commands
     ↓
REPOCLI Main CLI
     ↓
Configuration Manager
     ↓
Provider Wrapper (github.sh/gitlab.sh/gitea.sh)
     ↓
Native CLI Tool (gh/glab/tea)
     ↓
Git Hosting Platform
```

## 📁 Project Structure

```
repocli/
├── repocli                 # Main executable
├── lib/
│   ├── config.sh          # Configuration management
│   ├── utils.sh           # Utility functions
│   └── providers/
│       ├── github.sh      # GitHub provider
│       ├── gitlab.sh      # GitLab provider
│       ├── gitea.sh       # Gitea provider
│       └── codeberg.sh    # Codeberg provider
├── tests/                 # Test scripts
├── install.sh             # Installation script
└── README.md
```

## 🧪 Testing

Run the test suite:
```bash
cd repocli
./tests/run-tests.sh
```

Test specific provider:
```bash
./tests/test-github.sh
./tests/test-gitlab.sh
```

## 🤝 Contributing

We welcome contributions! Here's how to help:

### Adding New Providers
1. Create `lib/providers/newprovider.sh`
2. Implement `newprovider_execute()` function
3. Add provider to `config.sh` and main `repocli` script
4. Update documentation

### Improving Existing Providers
1. Check `lib/providers/*.sh` for the provider
2. Add new command mappings
3. Update tests
4. Document changes

### Development Setup
```bash
git clone https://github.com/quazardous/repocli.git
cd repocli

# Setup development environment
make dev-setup

# Test in development mode
./repocli --repocli-help
./repocli repocli:init

# Run tests
make test

# Check syntax
make lint
```

### Build & Distribution
```bash
# Install from source
make install

# Create distribution tarball
make dist

# Test Homebrew formula (requires brew)
make homebrew-test
```

## 🏆 Current Status

- **Version**: 1.0.0
- **Status**: Beta - Ready for initial release
- **Architecture**: Complete core functionality  
- **Providers**: GitHub (✅), GitLab (✅), Gitea (🚧), Codeberg (🚧)

### Current Development Priorities
1. **Complete Gitea Provider** - Essential for tea CLI support
2. **Complete Codeberg Provider** - Community-requested feature
3. **Release 1.0.0** - First stable release
4. **Enhanced Testing & Quality** - Ongoing improvements (Tasks #34, #35)

### Dependencies
- **Required**: bash, jq
- **Provider CLIs**: gh, glab, tea (depending on usage)
- **Build**: make (optional)
- **Package**: Homebrew (optional)

### Quality Gates
- All shell scripts pass `shellcheck`
- Test suite passes (unit + integration)
- Documentation is up-to-date
- No breaking changes in stable versions

## 🚀 Release Strategy
- **Semantic Versioning**: MAJOR.MINOR.PATCH
- **Release Branches**: release/vX.Y.Z
- **Hotfixes**: hotfix/vX.Y.Z-patch
- **Beta Releases**: vX.Y.Z-beta.N

## 📝 Evolution Roadmap

**Current Focus**: Completing core provider ecosystem (Gitea, Codeberg)

For detailed future plans and strategic roadmap, see our comprehensive product evolution plan:
- **Strategic Vision**: `.claude/prds/project-evo.md`
- **Cross-Provider Testing**: `.claude/prds/cross-testing.md`

**Next Major Features**: 
- Plugin architecture for extensibility
- Enterprise provider support (BitBucket, Azure DevOps)
- Workflow automation and templates

## 🐛 Troubleshooting

### Common Issues

**"repocli: command not found"**
```bash
# Check if installed
which repocli

# For user installation, ensure PATH includes ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
```

**"Provider CLI not found"**
```bash
# Install required CLI tool
# GitHub: https://cli.github.com/
# GitLab: https://gitlab.com/gitlab-org/cli
# Gitea/Codeberg: https://gitea.com/gitea/tea
```

**"Not authenticated"**
```bash
# Authenticate with your provider
repocli auth status  # Check status
gh auth login        # GitHub
glab auth login      # GitLab
tea login add        # Gitea/Codeberg
```

### Debug Mode
```bash
export REPOCLI_DEBUG=1
repocli issue view 123
```

## 📄 License

MIT License. See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **GitHub CLI** team for the excellent `gh` interface design
- **GitLab CLI** team for `glab` 
- **Gitea** team for `tea`
- All contributors to this project

## 📞 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/quazardous/repocli/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/quazardous/repocli/discussions)

---

**Made with ❤️ for the Git community**