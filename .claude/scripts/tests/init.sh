#!/bin/bash
# GitLab Cross-Testing Configuration Setup
# Interactive command to create .tests.conf for private repository testing

set -e

echo "🔧 GitLab Cross-Testing Configuration Setup"
echo "============================================"
echo

# 1. Prerequisites Check
echo "🔍 Checking prerequisites..."

# Check if glab CLI is available
if ! command -v glab >/dev/null 2>&1; then
    echo "❌ GitLab CLI 'glab' not found"
    echo
    echo "📦 Install GitLab CLI:"
    echo
    echo "🍺 Homebrew (macOS/Linux):"
    echo "  brew install glab"
    echo
    echo "📥 Direct Download:"
    echo "  https://gitlab.com/gitlab-org/cli/-/releases"
    echo
    echo "🐧 Linux Package Managers:"
    echo "  # Debian/Ubuntu"
    echo "  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
    echo "  sudo apt update && sudo apt install glab"
    echo
    echo "  # RHEL/Fedora/CentOS"
    echo "  sudo dnf install glab"
    echo
    echo "  # Arch Linux"
    echo "  sudo pacman -S glab"
    echo
    echo "📚 More info: https://gitlab.com/gitlab-org/cli#installation"
    exit 1
fi

echo "✅ GitLab CLI found: $(glab version 2>/dev/null || echo 'version unknown')"

# Check if .tests.conf already exists
if [ -f .tests.conf ]; then
    echo "⚠️ .tests.conf already exists"
    echo "This will overwrite your existing test configuration."
    read -p "Continue? (y/N): " confirm
    [[ "$confirm" != [yY] ]] && echo "Aborted." && exit 0
fi

# 2. Authentication Check
echo
echo "🔐 Checking GitLab authentication..."

# Check if user is authenticated to GitLab.com
if ! glab auth status >/dev/null 2>&1; then
    echo "⚠️ Not authenticated to GitLab"
    echo
    echo "You need to authenticate with GitLab first:"
    echo "  glab auth login"
    echo
    echo "This will guide you through browser-based authentication."
    echo "Run /tests:init again after authentication."
    exit 1
fi

echo "✅ GitLab authentication verified"

# 3. Interactive Configuration
echo
echo "🔧 GitLab Cross-Testing Configuration Setup"
echo "This will create a .tests.conf file for private repository testing."
echo

# GitLab instance URL
read -p "GitLab instance URL [https://gitlab.com]: " gitlab_instance
gitlab_instance=${gitlab_instance:-https://gitlab.com}

# Validate and normalize URL
gitlab_instance=$(echo "$gitlab_instance" | sed 's|/$||')  # Remove trailing slash
if [[ ! "$gitlab_instance" =~ ^https?:// ]]; then
    gitlab_instance="https://$gitlab_instance"
fi

# Private repository
echo
echo "Enter your private GitLab repository for testing:"
echo "Format: username/repository"
echo "Example: dberlioz/test_repocli"
read -p "GitLab repository: " gitlab_repo

if [[ -z "$gitlab_repo" ]]; then
    echo "❌ Repository is required"
    exit 1
fi

# Validate repository format
if [[ ! "$gitlab_repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "❌ Invalid repository format. Use: username/repository"
    exit 1
fi

# Optional test username  
read -p "Test username [optional]: " gitlab_user

# Test mode selection
echo
echo "Choose test mode:"
echo "  1) hybrid (default) - Use existing issues if available, create temporary ones if needed"
echo "  2) read-only - Only use read operations (issue list, repository info)"
echo "  3) auto-create - Always create temporary test issues (cleaned up after tests)"
echo "  4) existing-only - Only test with existing issues (fail if none available)"
read -p "Test mode [1]: " test_mode_choice

case "${test_mode_choice:-1}" in
    1) test_mode="hybrid" ;;
    2) test_mode="read_only" ;;
    3) test_mode="auto_create" ;;
    4) test_mode="existing_only" ;;
    *) test_mode="hybrid"; echo "Invalid choice, using hybrid mode" ;;
esac

echo "Selected test mode: $test_mode"

# 4. Repository Access Validation
echo
echo "🔍 Validating GitLab repository access..."

# Set GitLab host for custom instances
if [[ "$gitlab_instance" != "https://gitlab.com" ]]; then
    export GITLAB_HOST=$(echo "$gitlab_instance" | sed 's|^https\?://||')
fi

# Test repository access using GitLab API
if glab api "projects/$(echo "$gitlab_repo" | sed 's|/|%2F|g')" >/dev/null 2>&1; then
    echo "✅ Repository access validated"
else
    echo "❌ Cannot access repository: $gitlab_repo"
    echo
    echo "This could be due to:"
    echo "  1. Not authenticated with GitLab"
    echo "  2. No read access to the repository"
    echo "  3. Repository doesn't exist"
    echo
    echo "🔐 Authentication Setup:"
    echo
    if [[ "$gitlab_instance" != "https://gitlab.com" ]]; then
        hostname=$(echo "$gitlab_instance" | sed 's|^https\?://||')
        echo "For custom GitLab instance ($hostname):"
        echo "  glab auth login --hostname $hostname"
        echo
        echo "This will:"
        echo "  1. Open your browser for authentication"
        echo "  2. Create a personal access token"
        echo "  3. Store credentials securely"
    else
        echo "For GitLab.com:"
        echo "  glab auth login"
        echo
        echo "This will:"
        echo "  1. Open your browser for GitLab.com authentication"
        echo "  2. Create a personal access token"
        echo "  3. Store credentials securely"
    fi
    echo
    echo "📋 Manual Token Setup (alternative):"
    echo "  1. Go to: $gitlab_instance/-/profile/personal_access_tokens"
    echo "  2. Create token with 'read_api' scope"
    echo "  3. Set environment variable:"
    if [[ "$gitlab_instance" != "https://gitlab.com" ]]; then
        echo "     export GITLAB_TOKEN=your_token_here"
        echo "     export GITLAB_HOST=$(echo "$gitlab_instance" | sed 's|^https\?://||')"
    else
        echo "     export GITLAB_TOKEN=your_token_here"
    fi
    echo
    echo "🔍 Repository Access:"
    echo "  Make sure you have at least 'Reporter' access to: $gitlab_repo"
    echo
    echo "📚 More info: https://gitlab.com/gitlab-org/cli#authentication"
    exit 1
fi

# 5. Configuration File Creation
echo
echo "📝 Creating configuration files..."

# Generate timestamp
timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Create .tests.conf with proper permissions
cat > .tests.conf << EOF
# GitLab Cross-Testing Configuration
# Generated by /tests:init on $timestamp
# 
# ⚠️ SECURITY: This file contains references to private repositories
# Keep this file private and never commit it to version control

# GitLab instance URL
gitlab_test_instance=$gitlab_instance

# Private GitLab repository for testing
gitlab_test_repo=$gitlab_repo

# Test mode configuration
# - hybrid: Use existing issues if available, create temporary ones if needed (default)
# - read_only: Only use read operations (safest, limited testing)  
# - auto_create: Always create temporary test issues (most comprehensive)
# - existing_only: Only test with existing issues (fail if none available)
gitlab_test_mode=$test_mode

# Prefix for temporary test issues (used in auto_create and hybrid modes)
gitlab_test_prefix=[REPOCLI-TEST]
EOF

# Add optional fields if provided
[[ -n "$gitlab_user" ]] && echo "gitlab_test_user=$gitlab_user" >> .tests.conf

# Set restrictive permissions
chmod 600 .tests.conf
echo "✅ Created .tests.conf (permissions: 600)"

# 6. Example File and GitIgnore
# Create .tests.conf.example template
cat > .tests.conf.example << 'EOF'
# GitLab Cross-Testing Configuration Template
# Copy this file to .tests.conf and configure with your private repository

# GitLab instance URL (default: https://gitlab.com)
gitlab_test_instance=https://gitlab.com

# Private GitLab repository for testing (required)
# Format: username/repository
gitlab_test_repo=your-username/your-test-repo

# Test mode configuration
# - hybrid: Use existing issues if available, create temporary ones if needed (default)
# - read_only: Only use read operations (safest, limited testing)
# - auto_create: Always create temporary test issues (most comprehensive)  
# - existing_only: Only test with existing issues (fail if none available)
gitlab_test_mode=hybrid

# Optional: test username
gitlab_test_user=your-username

# Prefix for temporary test issues (used in auto_create and hybrid modes)
gitlab_test_prefix=[REPOCLI-TEST]
EOF
echo "✅ Created .tests.conf.example template"

# Update .gitignore if needed
if ! grep -q "^\.tests\.conf$" .gitignore 2>/dev/null; then
    echo ".tests.conf" >> .gitignore
    echo "✅ Added .tests.conf to .gitignore"
else
    echo "ℹ️ .tests.conf already in .gitignore"
fi

# 7. Success Message
echo
echo "🎉 GitLab cross-testing configuration complete!"
echo
echo "Configuration saved to .tests.conf:"
echo "  GitLab Instance: $gitlab_instance"
echo "  Repository: $gitlab_repo"
echo "  Test Mode: $test_mode"
[[ -n "$gitlab_user" ]] && echo "  Test User: $gitlab_user"
echo
echo "Next steps:"
echo "  1. Run cross-testing framework: make test"
echo "  2. Or run specific GitLab tests: ./tests/cross-testing/run-cross-tests.sh gitlab"
echo "  3. Validate setup: source .tests.conf && echo \"Repository: \$gitlab_test_repo\""
echo
echo "🔒 Security reminder:"
echo "  - .tests.conf contains private repository references"
echo "  - Keep this file secure and never commit it"
echo "  - File permissions set to 600 (owner read/write only)"
echo