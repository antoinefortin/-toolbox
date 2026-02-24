cat > ~/setup-wow-dev.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

echo "[1/6] Installing packages..."
sudo apt update
sudo apt install -y git curl neovim tmux tmuxp ripgrep fzf bat

echo "[2/6] Creating Neovim config..."
mkdir -p ~/.config/nvim

cat > ~/.config/nvim/init.lua <<'LUA'
-- ============================================================
-- Neovim "FULL FEEL" (SSH/Tmux friendly)
-- Path: ~/.config/nvim/init.lua
-- ============================================================

-- nvim-tree recommends disabling netrw at the very start [web:121]
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.updatetime = 200
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Cursor mode shapes (terminal must support it)
vim.opt.guicursor =
  "n-v-c:block," ..
  "i-ci:ver25," ..
  "r-cr:hor20," ..
  "o:hor50," ..
  "a:blinkwait700-blinkoff400-blinkon250"

-- lazy.nvim bootstrap (official pattern) [web:112]
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
  vim.fn.system({
    "git","clone","--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "nvim-tree/nvim-web-devicons" },

  -- Left file tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = { width = 32, side = "left" },
        renderer = { group_empty = true },
        filters = { dotfiles = false },
        actions = { open_file = { quit_on_open = false } },
      })
    end,
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function() require("telescope").setup({}) end,
  },

  -- Smooth scrolling
  {
    "karb94/neoscroll.nvim",
    config = function()
      require("neoscroll").setup({
        easing = "circular",
        hide_cursor = true,
        duration_multiplier = 1.15,
      })
    end,
  },

  -- Cursor smear/trail
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      smear_insert_mode = true,
      cursor_color = "none",
    },
  },
})

-- Auto-open tree on startup (left), keep focus on editor
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("nvim-tree.api").tree.open({ current_window = false })
    vim.cmd("wincmd p")
  end,
})

-- Keymaps
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Tree toggle" })
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Grep" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })

-- Bottom terminal inside Neovim when you want it
vim.keymap.set("n", "<leader>t", "<cmd>botright split | resize 12 | terminal<cr>", { desc = "Terminal bottom" })

-- Exit terminal mode easily (Neovim terminal docs: <C-\><C-n>) [web:164]
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal -> Normal" })

vim.keymap.set("n", "<leader>ss", "<cmd>SmearCursorToggle<cr>", { desc = "Toggle smear" })
LUA

echo "[3/6] Creating tmux status bar clock..."
cat > ~/.tmux.conf <<'TMUX'
set -g status on
set -g status-interval 1
set -g status-right '%Y-%m-%d %H:%M:%S'
TMUX

echo "[4/6] Creating tmuxp layout..."
mkdir -p ~/.tmuxp
cat > ~/.tmuxp/dev.yaml <<'YAML'
session_name: dev
start_directory: /home/debian
windows:
  - window_name: work
    layout: main-horizontal
    panes:
      - shell_command: nvim
      - shell_command: bash
YAML

echo "[5/6] Auto-load alive session on SSH login..."
# Append only if not already present
grep -q "tmuxp load -y dev" ~/.bashrc 2>/dev/null || cat >> ~/.bashrc <<'BASHRC'

# Auto-load/attach the persistent tmux workspace when SSH'ing in [web:326]
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
  tmuxp load -y dev
  exit
fi
BASHRC

echo "[6/6] Done."
echo "Reconnect via SSH. You should land inside tmux, Neovim opens, tree is left, and tmux clock is visible."
echo "Keys: Space+e tree, Space+t bottom terminal, Space+ff files, Space+fg grep."
BASH
chmod +x ~/setup-wow-dev.sh