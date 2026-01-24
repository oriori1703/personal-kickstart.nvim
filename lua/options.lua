-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.o.breakindent = true

-- Enable undo/redo changes even after closing and reopening a file
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-guide-options`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- Disable line wrapping
vim.o.wrap = false

-- Highlight max chars per line
vim.o.colorcolumn = '88'

-- same font as alacritty
vim.o.guifont = 'FiraCode Nerd Font:h11'

-- resize with ctrl + [0, -, +]
-- works in neovide and alacritty
vim.g.neovide_scale_factor = 1.0
local step = 1.05
local change_scale_factor = function(delta) vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta end
vim.keymap.set('n', '<C-=>', function() change_scale_factor(step) end)
vim.keymap.set('n', '<C-->', function() change_scale_factor(1 / step) end)
vim.keymap.set('n', '<C-0>', function() vim.g.neovide_scale_factor = 1.0 end)

-- Ctrl-Shift-v to paste
if vim.g.neovide then
  -- vim.keymap.set('n', '<D-s>', ':w<CR>') -- Save
  -- vim.keymap.set('v', '<D-c>', '"+y') -- Copy
  vim.keymap.set('n', '<sc-v>', '"+P') -- Paste normal mode
  vim.keymap.set('v', '<sc-v>', '"+P') -- Paste visual mode
  vim.keymap.set('c', '<sc-v>', '<C-R>+') -- Paste command mode
  -- vim.keymap.set('i', '<sc-v>', '<ESC>l"+Pli') -- Paste insert mode
  vim.keymap.set('i', '<sc-v>', '<ESC>"+p') -- Paste insert mode
  vim.keymap.set('t', '<sc-v>', '<C-\\><C-n>"+Pi', { noremap = true }) -- Paste terminal mode
end
-- vim: ts=2 sts=2 sw=2 et
