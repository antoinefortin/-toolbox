###############################################################################
#  install-cpp-layout.sh — Installs the C++ dev layout for tms
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${CYAN}${BOLD}Installing C++ dev layout...${NC}"
echo ""

# inotify-tools for fast file watching
if ! command -v inotifywait &>/dev/null; then
    echo "Installing inotify-tools..."
    sudo apt-get update -qq && sudo apt-get install -y inotify-tools
fi

# Ensure g++ is available
if ! command -v g++ &>/dev/null; then
    echo "Installing g++..."
    sudo apt-get install -y build-essential
fi

# Ensure tree is available
if ! command -v tree &>/dev/null; then
    sudo apt-get install -y tree
fi

mkdir -p ~/.local/bin ~/.tmux-layouts

# Install watcher
cp cpp-watch ~/.local/bin/cpp-watch
chmod +x ~/.local/bin/cpp-watch

# Install layout
cp cpp.sh ~/.tmux-layouts/cpp.sh
chmod +x ~/.tmux-layouts/cpp.sh

echo ""
echo -e "${GREEN}${BOLD}Done!${NC}"
echo ""
echo "  Usage:"
echo "    tms cpp        Launch C++ dev environment"
echo ""
echo "  Or standalone:"
echo "    bash ~/.tmux-layouts/cpp.sh"