-- Disable netrw (nvim-tree replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- ── Leader ─────────────────────────────────────────────────────
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ── Options ────────────────────────────────────────────────────
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.updatetime = 200
opt.timeoutlen = 300
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.showmode = false           -- lualine shows mode
opt.laststatus = 3             -- global statusline
opt.pumheight = 12             -- popup menu height
opt.completeopt = "menu,menuone,noselect"

-- Cursor shapes
opt.guicursor =
  "n-v-c:block," ..
  "i-ci:ver25," ..
  "r-cr:hor20," ..
  "o:hor50," ..
  "a:blinkwait700-blinkoff400-blinkon250"

-- ── Lazy.nvim bootstrap ────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
opt.rtp:prepend(lazypath)

-- ════════════════════════════════════════════════════════════════
--  PLUGINS
-- ════════════════════════════════════════════════════════════════
require("lazy").setup({

  -- ── Theme: Tokyo Night (matches tmux) ────────────────────────
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "night",
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
        },
        sidebars = { "qf", "help", "NvimTree" },
      })
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  -- ── Icons ────────────────────────────────────────────────────
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- ── File Tree (left panel) ───────────────────────────────────
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local api = require("nvim-tree.api")

      local function on_attach(bufnr)
        api.config.mappings.default_on_attach(bufnr)

        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end

        vim.keymap.set("n", "<CR>", function()
          local node = api.tree.get_node_under_cursor()
          if node then api.node.open.edit(node, { close_tree = false }) end
        end, opts("Open (keep tree)"))

        vim.keymap.set("n", "p", function()
          local node = api.tree.get_node_under_cursor()
          if node then api.node.open.preview(node) end
        end, opts("Preview"))
      end

      require("nvim-tree").setup({
        on_attach = on_attach,
        view = { width = 30, side = "left" },
        renderer = {
          group_empty = true,
          highlight_git = true,
          icons = {
            show = { file = true, folder = true, folder_arrow = true, git = true },
          },
        },
        filters = { dotfiles = false },
        actions = { open_file = { quit_on_open = false } },
        diagnostics = { enable = true },
      })
    end,
  },

  -- ── Treesitter (REAL syntax highlighting + more) ─────────────
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c", "cpp", "lua", "python", "bash", "javascript", "typescript",
          "html", "css", "json", "yaml", "toml", "markdown", "markdown_inline",
          "dockerfile", "make", "cmake", "vim", "vimdoc", "regex", "asm",
        },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = false,
            node_decremental = "<bs>",
          },
        },
      })
    end,
  },

  -- ── LSP (language servers) ───────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- C/C++ (clangd)
      lspconfig.clangd.setup({
        capabilities = capabilities,
        cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
      })

      -- Lua (for nvim config editing)
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      -- Keymaps on LSP attach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = "LSP: " .. desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("gi", vim.lsp.buf.implementation, "Implementation")
          map("K", vim.lsp.buf.hover, "Hover docs")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>D", vim.lsp.buf.type_definition, "Type definition")
          map("[d", vim.diagnostic.goto_prev, "Prev diagnostic")
          map("]d", vim.diagnostic.goto_next, "Next diagnostic")
          map("<leader>e", vim.diagnostic.open_float, "Show diagnostic")
        end,
      })

      -- Pretty diagnostic signs
      local signs = { Error = " ", Warn = " ", Hint = "󰌵 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end

      -- Floating window borders
      vim.diagnostic.config({
        float = { border = "rounded" },
        virtual_text = { prefix = "●", spacing = 4 },
        severity_sort = true,
      })
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })
    end,
  },

  -- ── Autocomplete ─────────────────────────────────────────────
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      local kind_icons = {
        Text = "󰉿", Method = "󰆧", Function = "󰊕", Constructor = "",
        Field = "󰜢", Variable = "󰀫", Class = "󰠱", Interface = "",
        Module = "", Property = "󰜢", Unit = "󰑭", Value = "󰎠",
        Enum = "", Keyword = "󰌋", Snippet = "", Color = "󰏘",
        File = "󰈙", Reference = "󰈇", Folder = "󰉋", EnumMember = "",
        Constant = "󰏿", Struct = "󰙅", Event = "", Operator = "󰆕",
        TypeParameter = "",
      }

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "buffer",   priority = 500 },
          { name = "path",     priority = 250 },
        }),
        formatting = {
          format = function(entry, vim_item)
            vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip  = "[Snip]",
              buffer   = "[Buf]",
              path     = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
      })
    end,
  },

  -- ── Telescope (fuzzy finder) ─────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          prompt_prefix = "   ",
          selection_caret = "  ",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
        },
      })
      pcall(telescope.load_extension, "fzf")
    end,
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Symbols" },
    },
  },

  -- ── Statusline (lualine) ─────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  -- ── Buffer tabs (top) ────────────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          themable = true,
          diagnostics = "nvim_lsp",
          offsets = {
            { filetype = "NvimTree", text = " Files", highlight = "Directory", separator = true },
          },
          separator_style = "thin",
          show_buffer_close_icons = false,
          show_close_icon = false,
        },
      })
    end,
  },

  -- ── Git signs in gutter ──────────────────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = "▎" },
          change       = { text = "▎" },
          delete       = { text = "" },
          topdelete    = { text = "" },
          changedelete = { text = "▎" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local map = function(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end
          map("n", "]h", gs.next_hunk, "Next hunk")
          map("n", "[h", gs.prev_hunk, "Prev hunk")
          map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>gb", gs.blame_line, "Blame line")
        end,
      })
    end,
  },

  -- ── Indent guides ────────────────────────────────────────────
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("ibl").setup({
        indent = { char = "│" },
        scope = { enabled = true, show_start = false, show_end = false },
      })
    end,
  },

  -- ── Autopairs ────────────────────────────────────────────────
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        check_ts = true,  -- treesitter aware
      })
      -- Integrate with cmp
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -- ── Smooth scrolling ────────────────────────────────────────
  {
    "karb94/neoscroll.nvim",
    config = function()
      require("neoscroll").setup({
        easing = "circular",
        hide_cursor = false,
      })
    end,
  },

  -- ── Cursor trail ─────────────────────────────────────────────
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      smear_between_buffers = true,
      smear_insert_mode = true,
    },
  },

  -- ── Which-key (shows keybind hints) ──────────────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup({
        window = { border = "rounded" },
      })
      wk.register({
        ["<leader>f"] = { name = " Find" },
        ["<leader>g"] = { name = " Git" },
        ["<leader>c"] = { name = " Code" },
        ["<leader>r"] = { name = " Rename" },
      })
    end,
  },

  -- ── Colorizer (shows hex colors inline) ──────────────────────
  {
    "norcalli/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("colorizer").setup({ "*" }, {
        RGB = true, RRGGBB = true, names = false, css = true,
      })
    end,
  },

  -- ── Todo comments highlighting ───────────────────────────────
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
    end,
  },

  -- ── Float preview for nvim-tree ──────────────────────────────
  { "JMarkin/nvim-tree.lua-float-preview" },

}, {
  -- Lazy.nvim UI config
  ui = { border = "rounded" },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})

-- ════════════════════════════════════════════════════════════════
--  KEYMAPS
-- ════════════════════════════════════════════════════════════════

local map = vim.keymap.set

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move left" })
map("n", "<C-j>", "<C-w>j", { desc = "Move down" })
map("n", "<C-k>", "<C-w>k", { desc = "Move up" })
map("n", "<C-l>", "<C-w>l", { desc = "Move right" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })

-- Clear search
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search" })

-- Better indenting
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move lines
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move up" })

-- Quick save
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>x", "<cmd>x<CR>", { desc = "Save & quit" })

-- Toggle tree
map("n", "<leader>n", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<leader>o", "<cmd>NvimTreeFocus<CR>", { desc = "Focus file tree" })

-- Terminal
local function open_bottom_terminal()
  vim.cmd("botright split | resize 12 | terminal")
end
map("n", "<leader>t", open_bottom_terminal, { desc = "Terminal bottom" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal → Normal" })

-- ════════════════════════════════════════════════════════════════
--  AUTOCOMMANDS
-- ════════════════════════════════════════════════════════════════

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Open tree + terminal on startup
autocmd("VimEnter", {
  group = augroup("startup_layout", { clear = true }),
  callback = function()
    -- Open file tree
    require("nvim-tree.api").tree.open({ current_window = false })
    -- Open bottom terminal
    vim.cmd("botright split | resize 12 | terminal")
    -- Focus back on editor (middle pane)
    vim.cmd("wincmd k")
  end,
})

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function() vim.highlight.on_yank({ timeout = 200 }) end,
})

-- Restore cursor position
autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-resize splits on window resize
autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  command = "tabdo wincmd =",
})

-- Close nvim if tree is the last window
autocmd("QuitPre", {
  group = augroup("auto_close_tree", { clear = true }),
  callback = function()
    local tree_wins = {}
    local floating_wins = {}
    local wins = vim.api.nvim_list_wins()
    for _, w in ipairs(wins) do
      local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
      if bufname:match("NvimTree_") then
        table.insert(tree_wins, w)
      end
      if vim.api.nvim_win_get_config(w).relative ~= "" then
        table.insert(floating_wins, w)
      end
    end
    if #wins - #floating_wins - #tree_wins == 1 then
      for _, w in ipairs(tree_wins) do
        vim.api.nvim_win_close(w, true)
      end
    end
  end,
})