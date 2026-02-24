#!/bin/bash
###############################################################################
#  install-nvim-deps.sh — Install LSP servers + deps for the nvim config
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${CYAN}${BOLD}Installing Neovim LSP dependencies...${NC}"
echo ""

# clangd for C/C++
if ! command -v clangd &>/dev/null; then
    echo "Installing clangd..."
    sudo apt-get update -qq && sudo apt-get install -y clangd
fi

# lua-language-server (for editing nvim config)
if ! command -v lua-language-server &>/dev/null; then
    echo "Installing lua-language-server..."
    sudo apt-get install -y lua-language-server 2>/dev/null || {
        echo "  Manual install needed — see https://github.com/LuaLS/lua-language-server"
    }
fi

# ripgrep (for Telescope live_grep)
if ! command -v rg &>/dev/null; then
    echo "Installing ripgrep..."
    sudo apt-get install -y ripgrep
fi

# fd (for Telescope find_files)
if ! command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    echo "Installing fd-find..."
    sudo apt-get install -y fd-find
fi

# gcc/g++ (for treesitter compilation)
if ! command -v gcc &>/dev/null; then
    echo "Installing build-essential..."
    sudo apt-get install -y build-essential
fi

echo ""
echo -e "${GREEN}${BOLD}Done!${NC}"
echo ""
echo "Now open nvim and let it install plugins:"
echo "  nvim"
echo ""
echo "First launch will take ~30s to download plugins + compile parsers."
echo "If you see errors, quit and reopen — sometimes lazy.nvim needs a second pass."