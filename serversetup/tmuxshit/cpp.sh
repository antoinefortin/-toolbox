#!/bin/bash
###############################################################################
#  cpp.sh — C++ Dev Layout for tms
#  ┌────────┬─────────────────────────┐
#  │  files │                         │
#  │  tree  │        neovim           │
#  │        │                         │
#  ├────────┴─────────────────────────┤
#  │  auto-compile & run (watcher)    │
#  └──────────────────────────────────┘
#  Bottom pane watches for .cpp/.h saves → compile → run
###############################################################################

SESSION="cpp"
WATCHER="$HOME/.local/bin/cpp-watch"

# ── Ask for project location ────────────────────────────────────
echo -e "\033[0;36mC++ Project Setup\033[0m"
echo ""
read -rp "  Project parent dir [~/projects]: " parent_dir
parent_dir="${parent_dir:-$HOME/projects}"
parent_dir="${parent_dir/#\~/$HOME}"

read -rp "  Project name: " project_name

if [[ -z "$project_name" ]]; then
    echo "Need a project name."
    exit 1
fi

DIR="$parent_dir/$project_name"

# ── Create project ──────────────────────────────────────────────
if [[ -d "$DIR" ]]; then
    echo -e "\033[1;33m  Project exists — opening it.\033[0m"
else
    mkdir -p "$DIR"

    cat > "$DIR/main.cpp" << 'CPPFILE'
#include <iostream>

int main() {
    std::cout << "Hello, world!" << std::endl;
    return 0;
}
CPPFILE

    cat > "$DIR/Makefile" << 'MAKEFILE'
CXX      := g++
CXXFLAGS := -std=c++17 -Wall -Wextra -Wpedantic -g
LDFLAGS  :=

SRC      := $(wildcard *.cpp)
OBJ      := $(SRC:.cpp=.o)
TARGET   := main

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJ)
        $(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
        $(CXX) $(CXXFLAGS) -c $<

run: all
        @echo ""
        @echo "─── output ───────────────────────────────"
        @./$(TARGET)
        @echo ""
        @echo "───────────────────────────── exit: $$?"

clean:
        rm -f $(OBJ) $(TARGET)
MAKEFILE

    echo -e "\033[0;32m  Created $DIR with main.cpp + Makefile\033[0m"
fi

# ── Ensure watcher script exists ────────────────────────────────
if [[ ! -f "$WATCHER" ]]; then
    echo -e "\033[1;33m  cpp-watch not found — run the setup first.\033[0m"
    exit 1
fi

# ── Launch tmux session ─────────────────────────────────────────
tmux new-session -d -s "$SESSION" -c "$DIR"
tmux rename-window -t "$SESSION:1" "$project_name"

# Left pane: file tree (auto-refreshing)
tmux send-keys -t "$SESSION:1" "watch -n2 -t 'tree -C --dirsfirst -I \"*.o|main\" . 2>/dev/null || ls -la'" C-m

# Center pane: neovim
tmux split-window -h -t "$SESSION:1" -c "$DIR" -p 80
tmux send-keys -t "$SESSION:1.2" "nvim main.cpp" C-m

# Bottom pane: watcher
tmux split-window -v -t "$SESSION:1.2" -c "$DIR" -p 25
tmux send-keys -t "$SESSION:1.3" "cpp-watch" C-m

# Focus editor
tmux select-pane -t "$SESSION:1.2"