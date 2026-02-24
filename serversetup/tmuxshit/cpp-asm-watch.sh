#!/bin/bash
###############################################################################
#  cpp-asm-watch — Auto-generate & display assembly on save
#  Watches .cpp/.h files, regenerates Intel syntax assembly
#  Color-coded output: labels, instructions, comments, registers
###############################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

DIR="${1:-.}"
cd "$DIR" || exit 1

# ── Assembly colorizer ──────────────────────────────────────────
colorize_asm() {
    while IFS= read -r line; do
        # Skip noise lines (directives we don't care about)
        if [[ "$line" =~ ^[[:space:]]*\.(cfi_|file|ident|section|type|size|globl|text|align) ]]; then
            continue
        fi

        # Empty line
        if [[ -z "${line// }" ]]; then
            echo ""
            continue
        fi

        # Labels (lines ending with :)
        if [[ "$line" =~ ^[^[:space:]].*:$ ]]; then
            echo -e "${GREEN}${BOLD}${line}${NC}"
            continue
        fi

        # Comments
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            echo -e "${DIM}${line}${NC}"
            continue
        fi

        # Source line markers (.loc)
        if [[ "$line" =~ ^[[:space:]]*\.loc ]]; then
            continue
        fi

        # Instructions — highlight mnemonics and registers
        local colored="$line"

        # Highlight registers (rax, eax, rdi, rsi, etc.)
        colored=$(echo "$colored" | sed -E \
            -e "s/%(r[a-z][a-z0-9]*|e[a-z][a-z]|[a-z]{2}l|[a-z]{2}h|rsp|rbp|rip|xmm[0-9]+)/\\\\033[0;33m%\1\\\\033[0m/g" \
            -e "s/\b(rax|rbx|rcx|rdx|rsi|rdi|rsp|rbp|r[0-9]+[dwb]?|eax|ebx|ecx|edx|esi|edi|esp|ebp|xmm[0-9]+)\b/\\\\033[0;33m\1\\\\033[0m/g")

        # Highlight jump/call instructions
        colored=$(echo "$colored" | sed -E \
            "s/^([[:space:]]*)(call|jmp|je|jne|jg|jge|jl|jle|ja|jae|jb|jbe|jz|jnz|jo|jno|js|jns|ret)/\1\\\\033[0;31m\2\\\\033[0m/")

        # Highlight mov/lea/push/pop
        colored=$(echo "$colored" | sed -E \
            "s/^([[:space:]]*)(mov[a-z]*|lea|push|pop)/\1\\\\033[0;36m\2\\\\033[0m/")

        # Highlight arithmetic
        colored=$(echo "$colored" | sed -E \
            "s/^([[:space:]]*)(add|sub|mul|imul|div|idiv|inc|dec|neg|not|and|or|xor|shl|shr|sar|sal|cmp|test)/\1\\\\033[0;35m\2\\\\033[0m/")

        echo -e "$colored"
    done
}

# ── Generate and display assembly ───────────────────────────────
show_asm() {
    clear
    echo -e "${CYAN}${BOLD}  asm-view${NC}${DIM}  $(pwd) │ $(date +%H:%M:%S)${NC}"
    echo -e "${DIM}  Intel syntax │ noise filtered │ saves trigger refresh${NC}"
    echo -e "${DIM}──────────────────────────────────────────────────${NC}"
    echo ""

    # Generate assembly (Intel syntax, minimal noise)
    local asm_output
    asm_output=$(g++ -std=c++17 -S -masm=intel \
        -fno-asynchronous-unwind-tables \
        -fno-exceptions \
        -fno-rtti \
        -fverbose-asm \
        -g \
        -o /dev/stdout \
        *.cpp 2>&1)

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}${BOLD}  ✗ Compilation failed${NC}"
        echo ""
        echo "$asm_output"
        return
    fi

    # Filter and colorize
    echo "$asm_output" | colorize_asm

    echo ""
    echo -e "${DIM}──────────────────────────────────────────────────${NC}"

    # Show stats
    local total_lines
    total_lines=$(echo "$asm_output" | wc -l)
    local instr_lines
    instr_lines=$(echo "$asm_output" | grep -cE '^[[:space:]]+(mov|push|pop|call|jmp|j[a-z]+|add|sub|mul|div|lea|cmp|test|ret|xor|and|or|shl|shr|nop|inc|dec)' || echo 0)
    echo -e "${DIM}  ${total_lines} total lines │ ~${instr_lines} instructions${NC}"
}

# ── Optimization level toggle ───────────────────────────────────
OPT_LEVEL=""  # empty = no optimization

# ── Main ────────────────────────────────────────────────────────
show_asm

# ── Watch loop ──────────────────────────────────────────────────
if command -v inotifywait &>/dev/null; then
    while true; do
        inotifywait -qq -e close_write -e moved_to \
            --include '\.(cpp|cc|cxx|h|hpp)$' \
            . 2>/dev/null
        sleep 0.2
        show_asm
    done
else
    echo -e "${YELLOW}  inotify-tools not found — using polling${NC}"

    get_hash() {
        find . -maxdepth 2 \( -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) 2>/dev/null \
            | sort | xargs md5sum 2>/dev/null
    }

    last_hash=$(get_hash)
    while true; do
        sleep 1
        current_hash=$(get_hash)
        if [[ "$current_hash" != "$last_hash" ]]; then
            last_hash="$current_hash"
            show_asm
        fi
    done
fi