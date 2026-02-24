#!/bin/bash
###############################################################################
#  cpp-debug.sh — C++ Debug Layout for tms
#  ┌──────────────────┬─────────────────────┐
#  │                  │                     │
#  │   assembly       │      neovim         │
#  │   (auto-refresh) │                     │
#  │                  │                     │
#  ├──────────────────┴─────────────────────┤
#  │            gdb (step-by-step)          │
#  └────────────────────────────────────────┘
#  Left: auto-generated assembly, refreshes on save
#  Right: editor
#  Bottom: gdb with TUI for line-by-line execution
###############################################################################

SESSION="cpp-debug"
ASM_WATCHER="$HOME/.local/bin/cpp-asm-watch"

# ── Find project ────────────────────────────────────────────────
echo -e "\033[0;36mC++ Debug Session\033[0m"
echo ""
read -rp "  Project path [~/projects/HelloTest]: " project_dir
project_dir="${project_dir:-$HOME/projects/HelloTest}"
project_dir="${project_dir/#\~/$HOME}"

if [[ ! -d "$project_dir" ]]; then
    echo -e "\033[0;31m  Directory not found: $project_dir\033[0m"
    exit 1
fi

if [[ ! -f "$project_dir/main.cpp" ]]; then
    echo -e "\033[0;31m  No main.cpp found in $project_dir\033[0m"
    exit 1
fi

DIR="$project_dir"

# ── Ensure watcher exists ───────────────────────────────────────
if [[ ! -f "$ASM_WATCHER" ]]; then
    echo -e "\033[1;33m  cpp-asm-watch not found — install it first.\033[0m"
    exit 1
fi

# ── Compile with debug symbols first ────────────────────────────
echo -e "\033[0;32m  Building with debug symbols...\033[0m"
cd "$DIR"
g++ -std=c++17 -Wall -Wextra -g -o main *.cpp 2>/dev/null
# Generate initial assembly
g++ -std=c++17 -S -masm=intel -fno-asynchronous-unwind-tables -fno-exceptions *.cpp -o main.s 2>/dev/null

# ── Launch tmux session ─────────────────────────────────────────
tmux new-session -d -s "$SESSION" -c "$DIR"
tmux rename-window -t "$SESSION:1" "debug"

# Left pane: assembly viewer (auto-refreshing)
tmux send-keys -t "$SESSION:1" "cpp-asm-watch" C-m

# Right pane: neovim
tmux split-window -h -t "$SESSION:1" -c "$DIR" -p 60
tmux send-keys -t "$SESSION:1.2" "nvim main.cpp" C-m

# Bottom pane: GDB
tmux split-window -v -t "$SESSION:1.2" -c "$DIR" -p 35
tmux send-keys -t "$SESSION:1.3" "echo -e '\\033[0;36m── GDB Quick Reference ──\\033[0m'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  r          run program'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  b main     breakpoint at main'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  b 6        breakpoint at line 6'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  n          next line (step over)'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  s          step into function'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  c          continue to next breakpoint'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  p var      print variable'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  l          list source around current line'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  bt         backtrace (call stack)'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  disas      show assembly of current function'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  ni         next instruction (asm step)'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  si         step into (asm level)'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  info reg   show registers'" C-m
tmux send-keys -t "$SESSION:1.3" "echo '  q          quit gdb'" C-m
tmux send-keys -t "$SESSION:1.3" "echo ''" C-m
tmux send-keys -t "$SESSION:1.3" "echo -e '\\033[0;33mStarting GDB...\\033[0m'" C-m
tmux send-keys -t "$SESSION:1.3" "gdb -q -tui ./main" C-m

# Window 2: plain shell for manual builds/tests
tmux new-window -t "$SESSION" -n "shell" -c "$DIR"
tmux send-keys -t "$SESSION:2" "echo '── Build & test shell ── use: make clean && make'" C-m

# Focus on editor
tmux select-window -t "$SESSION:1"
tmux select-pane -t "$SESSION:1.2"
