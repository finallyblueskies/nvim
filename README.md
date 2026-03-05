# nvim

A minimal, hyper-focused Neovim configuration aiming to strike a balance between the core features needed for effective codebase navigation while staying as distraction-free as possible.

Everything lives in a single `init.lua` (~200 lines).

## Plugins

| Plugin | Purpose |
|--------|---------|
| [lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting and code parsing |
| [cursor-dark.nvim](https://github.com/ydkulks/cursor-dark.nvim) | Colorscheme |
| [mini.pick](https://github.com/nvim-mini/mini.pick) | Fuzzy finder (files, grep, LSP) |
| [mini.extra](https://github.com/nvim-mini/mini.extra) | Additional pickers (LSP references, definitions) |
| [diffview.nvim](https://github.com/dlyongemallo/diffview.nvim) | Side-by-side git diffs and file history |

## Keybindings

**Leader:** `<Space>`

### Files & Search

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (hidden, respects .gitignore) |
| `<leader>fg` | Live grep (case-insensitive) |
| `<leader>fs` | LSP workspace symbols (scoped to git repo) |

### LSP

| Key | Action |
|-----|--------|
| `<leader>fd` | Find definition(s) |
| `<leader>fr` | Find references |
| `<leader>fi` | Find implementation |

### Git

| Key | Action |
|-----|--------|
| `<leader>gd` | Diff all files |
| `<leader>gh` | Current file history |
| `<leader>gH` | Full repo history |
| `<leader>gm` | Diff against main |
| `<leader>gq` | Close diffview |

## LSP

Uses Neovim 0.11's built-in `vim.lsp.config` (no nvim-lspconfig dependency). Currently configured for Swift via `sourcekit-lsp`.

## Requirements

- Neovim 0.11+
- [ripgrep](https://github.com/BurntSushi/ripgrep) (for file/grep pickers)
