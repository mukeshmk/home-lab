#!/usr/bin/env bash
# LXC Command Installer
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
REPO_RAW_URL="https://raw.githubusercontent.com/mukeshmk/home-lab/main/lxc"

# Detect if we are running from a local clone or remotely via curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
IS_REMOTE=false

if [[ ! -f "$SCRIPT_DIR/lxc" ]]; then
    IS_REMOTE=true
    # Check for curl if remote
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: 'curl' is required for remote installation.${NC}"
        exit 1
    fi
fi

# Helper to fetch files (local or remote)
fetch_file() {
    local src_name="$1"
    local dest_path="$2"

    if [ "$IS_REMOTE" = true ]; then
        curl -fsSL "$REPO_RAW_URL/lxc/$src_name" -o "$dest_path"
    else
        cp "$SCRIPT_DIR/$src_name" "$dest_path"
    fi
}

echo -e "${BLUE}Installing LXC CLI Router...${NC}"
if [ "$IS_REMOTE" = true ]; then
    echo -e "${BLUE}Mode: Remote installation from GitHub${NC}"
else
    echo -e "${BLUE}Mode: Local installation${NC}"
fi

# 1. Create the destination directory
mkdir -p "$INSTALL_DIR"

# 2. Copy files
echo "Installing lxc to $INSTALL_DIR..."
fetch_file "lxc" "$INSTALL_DIR/lxc"
fetch_file "lxc-completion.sh" "$INSTALL_DIR/lxc-completion.sh"

# 3. Make executable
chmod +x "$INSTALL_DIR/lxc"

# 4. Detect shell and set up PATH & Auto-completion
SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    if [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
fi

if [ -n "$SHELL_RC" ]; then
    # Create the LXC Manager block if it doesn't exist
    if ! grep -q '# >>> LXC Manager >>>' "$SHELL_RC"; then
        echo -e "\n${BLUE}Initializing LXC Manager block in $(basename "$SHELL_RC")...${NC}"
        echo "" >> "$SHELL_RC"
        echo '# >>> LXC Manager >>>' >> "$SHELL_RC"
        echo '# <<< LXC Manager <<<' >> "$SHELL_RC"
    fi

    # Function to add a line inside the block if it's missing
    add_to_lxc_block() {
        local line="$1"
        if ! grep -Fq "$line" "$SHELL_RC"; then
            # Insert before the closing marker using awk (portable on macOS/Darwin)
            awk -v line="$line" '/# <<< LXC Manager <<</ { print line } { print }' "$SHELL_RC" > "${SHELL_RC}.tmp" && \
            mv "${SHELL_RC}.tmp" "$SHELL_RC"
            return 0
        fi
        return 0
    }

    # Setup PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && ! grep -q '.local/bin' "$SHELL_RC"; then
        echo -e "\n${YELLOW}Adding $INSTALL_DIR to your PATH in $(basename "$SHELL_RC")...${NC}"
        add_to_lxc_block 'export PATH="$HOME/.local/bin:$PATH"'
    else
        echo -e "\nPATH already configured in $(basename "$SHELL_RC")."
    fi

    # Setup Auto-completion
    if ! grep -q "lxc-completion.sh" "$SHELL_RC"; then
        echo -e "${YELLOW}Adding auto-completion to $(basename "$SHELL_RC")...${NC}"
        
        # Zsh needs bashcompinit to run bash completion scripts properly
        if [[ "$SHELL" == */zsh ]]; then
            add_to_lxc_block 'autoload -Uz compinit && compinit'
            add_to_lxc_block 'autoload -Uz bashcompinit && bashcompinit'
        fi
        
        add_to_lxc_block "source \"$INSTALL_DIR/lxc-completion.sh\""
    else
        echo -e "Auto-completion already configured in $(basename "$SHELL_RC")."
    fi
else
    echo -e "\n${YELLOW}Warning: Could not detect bash or zsh configuration file.${NC}"
    echo -e "Please ensure '$INSTALL_DIR' is in your PATH manually."
fi

echo -e "\n${GREEN}✓ LXC CLI installation complete!${NC}"
echo -e "To start using your new 'lxc' command, open a new terminal tab, or run:"
echo -e "  ${BLUE}source $SHELL_RC${NC}"
