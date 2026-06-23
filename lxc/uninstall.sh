#!/usr/bin/env bash
# LXC Command Uninstaller
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"

echo -e "${BLUE}Uninstalling LXC Command...${NC}"

# 1. Remove files
if [ -f "$INSTALL_DIR/lxc" ]; then
    rm "$INSTALL_DIR/lxc"
    echo "  ✓ Removed lxc router"
else
    echo "  - lxc router not found"
fi

if [ -f "$INSTALL_DIR/lxc-completion.sh" ]; then
    rm "$INSTALL_DIR/lxc-completion.sh"
    echo "  ✓ Removed lxc-completion script"
else
    echo "  - lxc-completion script not found"
fi

# 2. Clean up shell configuration
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

if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
    echo -e "\n${YELLOW}Cleaning up shell configuration in $(basename "$SHELL_RC")...${NC}"
    
    # Create a backup
    cp "$SHELL_RC" "${SHELL_RC}.lxc-backup"
    echo "  ✓ Created backup: ${SHELL_RC}.lxc-backup"
    
    # Remove the LXC Manager block portably using awk
    awk '/# >>> LXC Manager >>>/{skip=1;next}/# <<< LXC Manager <<</{skip=0;next}!skip' "$SHELL_RC" > "${SHELL_RC}.tmp" && \
    mv "${SHELL_RC}.tmp" "$SHELL_RC"
    
    echo -e "${GREEN}✓ Shell configuration cleaned${NC}"
    echo -e "  If you want to restore the original, use: ${SHELL_RC}.lxc-backup"
else
    echo -e "\n${YELLOW}Could not find shell configuration file to clean up.${NC}"
fi

echo -e "\n${GREEN}✓ Uninstallation complete!${NC}"
echo -e "To complete the uninstallation, open a new terminal tab, or run:"
echo -e "  ${BLUE}source $SHELL_RC${NC}"
