-- Bootstrap lazy.nvim plugin manager: auto-clone if not already installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Core editor settings (must be set before lazy.nvim loads)
vim.g.mapleader = " "         -- Space as leader key
vim.g.maplocalleader = "\\"   -- Backslash as local leader
vim.o.clipboard = "unnamedplus" -- Use system clipboard for yank/paste
vim.opt.number = true           -- Show line numbers

-- Plugin declarations via lazy.nvim
require("lazy").setup({
	spec = {
		-- Treesitter: syntax highlighting and code parsing
		{
			'nvim-treesitter/nvim-treesitter',
			lazy = false,
			build = ':TSUpdate'
		},
		-- Colorscheme: Cursor-inspired dark theme
		{
			'ydkulks/cursor-dark.nvim',
			lazy = false,
			priority = 1000, -- load before other plugins
			config = function()
				require("cursor-dark").setup({
					transparent = false,
					style = "dark-midnight",
				})
				vim.cmd('colorscheme cursor-dark')

				-- Custom highlights for mini.pick fuzzy finder
				vim.api.nvim_set_hl(0, 'MiniPickMatchCurrent', { bg = '#3a3a5c', bold = true })
				vim.api.nvim_set_hl(0, 'MiniPickMatchRanges', { fg = '#ff9e64', bold = true })
				vim.api.nvim_set_hl(0, 'MiniPickBorder', { fg = '#7aa2f7' })
				vim.api.nvim_set_hl(0, 'MiniPickPrompt', { fg = '#7aa2f7', bold = true })

				-- Diffview: use subtle red background instead of fill chars for deleted lines
				vim.opt.fillchars:append({ diff = ' ' })
				vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#2d1b1e' })
			end,
		},
		-- mini.pick: fuzzy finder (file picker, grep, etc.)
		{
			'nvim-mini/mini.pick',
			version = '*',
			config = function()
				require('mini.pick').setup({
					source = {
						-- Override match to be case-insensitive
						match = function(stritems, inds, query)
							local lquery = {}
							for _, c in ipairs(query) do
								table.insert(lquery, c:lower())
							end
							local lower_items = {}
							for _, s in ipairs(stritems) do
								table.insert(lower_items, s:lower())
							end
							return MiniPick.default_match(lower_items, inds, lquery)
						end,
					}
				})
			end,
		},
		-- mini.extra: additional pickers (LSP symbols, references, etc.)
		{
			'nvim-mini/mini.extra',
			version = '*',
			config = function()
				require('mini.extra').setup()
			end,
		},
		-- Diffview: side-by-side git diffs and file history
		{
			'sindrets/diffview.nvim',
			cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
			keys = {
				{ '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Git diff (all files)' },
				{ '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'Git file history' },
				{ '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'Git repo history' },
				{ '<leader>gm', '<cmd>DiffviewOpen main<cr>', desc = 'Git diff vs main' },
				{ '<leader>gq', '<cmd>DiffviewClose<cr>', desc = 'Close diffview' },
			},
			opts = {},
		},
	},
	-- Auto-check for plugin updates
	checker = { enabled = true },
})

-- <leader>ff: find files (respects .gitignore, includes hidden files)
vim.keymap.set('n', '<leader>ff', function()
	MiniPick.builtin.files({ tool = 'rg', tool_args = { '--files', '--hidden', '--glob', '!.git' } })
end, { desc = 'Find files' })

-- <leader>fg: live grep across project
vim.keymap.set('n', '<leader>fg', function()
	MiniPick.builtin.grep_live({ tool = 'rg', tool_args = { '--ignore-case' } })
end, { desc = 'Live grep' })

-- <leader>fs: LSP workspace symbol search scoped to current git repo
vim.keymap.set('n', '<leader>fs', function()
	local git_root = vim.trim(vim.fn.system('git rev-parse --show-toplevel'))
	if vim.v.shell_error ~= 0 then
		vim.notify('Not in a git repository', vim.log.levels.WARN)
		return
	end

	local current_query = ''

	-- Callback: filter results to git repo, format for display, sort by relevance
	local function on_list(data)
		local items = {}
		for _, item in ipairs(data.items) do
			if item.filename and vim.startswith(item.filename, git_root) then
				local rel_path = vim.fn.fnamemodify(item.filename, ':.')
				local symbol = item.text or ''
				local suffix = symbol == '' and '' or (' │ ' .. symbol)
				item.text = string.format('%s│%s│%s%s', rel_path, item.lnum or 1, item.col or 1, suffix)
				item.path = item.filename
				item._symbol = symbol
				table.insert(items, item)
			end
		end

		-- Sort: prefix matches first, then contains, then alphabetical
		local q = current_query:lower()
		table.sort(items, function(a, b)
			local as = (a._symbol or ''):lower()
			local bs = (b._symbol or ''):lower()
			local a_prefix = as:sub(1, #q) == q
			local b_prefix = bs:sub(1, #q) == q
			if a_prefix ~= b_prefix then return a_prefix end
			local a_pos = as:find(q, 1, true)
			local b_pos = bs:find(q, 1, true)
			if (a_pos ~= nil) ~= (b_pos ~= nil) then return a_pos ~= nil end
			if a_pos and b_pos then return a_pos < b_pos end
			return as < bs
		end)

		if MiniPick.is_picker_active() then
			MiniPick.set_picker_items(items, { do_match = false })
		end
	end

	-- Custom picker: queries LSP on each keystroke instead of pre-loading items
	MiniPick.start({
		source = {
			name = 'Workspace Symbols',
			items = {},
			match = function(_, _, query)
				if #query == 0 then return MiniPick.set_picker_items({}, { do_match = false }) end
				current_query = table.concat(query)
				local win_id = MiniPick.get_picker_state().windows.target
				local buf_id = vim.api.nvim_win_get_buf(win_id)
				vim.api.nvim_buf_call(buf_id, function()
					vim.lsp.buf.workspace_symbol(current_query, { on_list = on_list })
				end)
			end,
		},
	})
end, { desc = 'Workspace symbols (git)' })

-- Helper: open an LSP picker that shows all results without further filtering
local function lsp_pick(scope)
	return function()
		MiniExtra.pickers.lsp({ scope = scope }, {
			source = {
				match = function(stritems, inds, query)
					return inds
				end,
			},
		})
	end
end

-- <leader>fr/fd/fi: LSP references, definition, implementation via mini.pick
vim.keymap.set('n', '<leader>fr', lsp_pick('references'), { desc = 'Find references' })
vim.keymap.set('n', '<leader>fd', lsp_pick('definition'), { desc = 'Find definition' })
vim.keymap.set('n', '<leader>fi', lsp_pick('implementation'), { desc = 'Find implementation' })

-- LSP: Swift via sourcekit-lsp (Neovim 0.11+ built-in LSP config)
vim.lsp.config('sourcekit', {
	cmd = { 'xcrun', 'sourcekit-lsp' },
	filetypes = { 'swift' },
	root_markers = { 'buildServer.json', '*.xcodeproj', '*.xcworkspace', 'Package.swift', '.git' },
	capabilities = {
		workspace = {
			didChangeWatchedFiles = {
				dynamicRegistration = true,
			},
		},
	},
})

vim.lsp.enable('sourcekit')

