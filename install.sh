#!/bin/bash
# REPOCLI Installation Script

set -euo pipefail

VERSION="1.0.0"
REPO_URL="https://github.com/quazardous/repocli"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root. Consider using --user flag for user installation."
    fi
}

# Detect installation method
detect_install_method() {
    # Check if we're being run by Homebrew
    if [[ -n "${HOMEBREW_PREFIX:-}" ]] && [[ "${1:-}" != "--user" ]]; then
        INSTALL_DIR="$HOMEBREW_PREFIX"
        BIN_DIR="$INSTALL_DIR/bin"
        LIB_DIR="$INSTALL_DIR/lib/repocli"
        info "Installing to Homebrew directory: $INSTALL_DIR"
        IS_HOMEBREW=true
    elif [[ "${1:-}" == "--user" ]]; then
        INSTALL_DIR="$HOME/.local"
        BIN_DIR="$INSTALL_DIR/bin"
        LIB_DIR="$INSTALL_DIR/lib/repocli"
        info "Installing to user directory: $INSTALL_DIR"
        IS_HOMEBREW=false
    else
        INSTALL_DIR="/usr/local"
        BIN_DIR="$INSTALL_DIR/bin"
        LIB_DIR="$INSTALL_DIR/lib/repocli"
        info "Installing to system directory: $INSTALL_DIR"
        IS_HOMEBREW=false
        
        # Check if we have write permissions
        if [[ ! -w "$INSTALL_DIR" ]]; then
            error "No write permission to $INSTALL_DIR. Try:"
            echo "  sudo $0        # System installation"
            echo "  $0 --user      # User installation"
            echo "  brew install repocli  # Homebrew installation"
            exit 1
        fi
    fi
}

# Create directories
create_directories() {
    info "Creating directories..."
    mkdir -p "$BIN_DIR"
    mkdir -p "$LIB_DIR/providers"
}

# Install files
install_files() {
    info "Installing files..."
    
    # Copy main executable
    cp repocli "$BIN_DIR/"
    chmod +x "$BIN_DIR/repocli"
    
    # Copy library files
    cp lib/*.sh "$LIB_DIR/"
    cp lib/providers/*.sh "$LIB_DIR/providers/"
    
    success "Files installed successfully"
}

# Update PATH if needed
update_path() {
    # Skip PATH updates for Homebrew installations - Homebrew handles this
    if [[ "${IS_HOMEBREW:-false}" == "true" ]]; then
        info "Homebrew will handle PATH configuration"
        return 0
    fi
    
    if [[ "$BIN_DIR" != "/usr/local/bin" ]] && [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        info "Adding $BIN_DIR to PATH..."
        
        local shell_config=""
        case "$SHELL" in
            */bash) shell_config="$HOME/.bashrc" ;;
            */zsh) shell_config="$HOME/.zshrc" ;;
            */fish) shell_config="$HOME/.config/fish/config.fish" ;;
            *) shell_config="$HOME/.profile" ;;
        esac
        
        if [[ "$SHELL" == */fish ]]; then
            echo "set -gx PATH $BIN_DIR \$PATH" >> "$shell_config"
        else
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$shell_config"
        fi
        
        warning "Added $BIN_DIR to PATH in $shell_config"
        warning "Please restart your shell or run: source $shell_config"
    fi
}

# Verify installation
verify_installation() {
    info "Verifying installation..."
    
    if command -v repocli &> /dev/null; then
        success "REPOCLI installed successfully!"
        info "Version: $(repocli --version)"
    else
        error "Installation verification failed"
        exit 1
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    success "🎉 Installation Complete!"
    echo ""
    info "Next steps:"
    echo "  1. Configure your provider:"
    echo "     repocli init"
    echo ""
    echo "  2. Test authentication:"
    echo "     repocli auth status"
    echo ""
    echo "  3. Start using repocli:"
    echo "     repocli issue list"
    echo "     repocli --help"
    echo ""
    info "Documentation: $REPO_URL"
}

# Uninstall function
uninstall() {
    info "Uninstalling REPOCLI..."
    
    local bin_file="$BIN_DIR/repocli"
    local lib_dir="$LIB_DIR"
    
    if [[ -f "$bin_file" ]]; then
        rm "$bin_file"
        success "Removed $bin_file"
    fi
    
    if [[ -d "$lib_dir" ]]; then
        rm -rf "$lib_dir"
        success "Removed $lib_dir"
    fi
    
    success "REPOCLI uninstalled successfully"
}

# Main installation
main() {
    echo ""
    echo "🔧 REPOCLI Installer v$VERSION"
    echo "=============================="
    echo ""
    
    # Handle uninstall
    if [[ "${1:-}" == "--uninstall" ]]; then
        check_root
        detect_install_method "${2:-}"
        uninstall
        exit 0
    fi
    
    # Handle help
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --user        Install to user directory (~/.local)"
        echo "  --uninstall   Uninstall REPOCLI"
        echo "  --help, -h    Show this help"
        echo ""
        echo "Examples:"
        echo "  $0            # System installation (requires sudo)"
        echo "  $0 --user     # User installation"
        echo "  $0 --uninstall --user  # Uninstall from user directory"
        exit 0
    fi
    
    # Install
    check_root
    detect_install_method "${1:-}"
    create_directories
    install_files
    update_path
    verify_installation
    show_next_steps
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi