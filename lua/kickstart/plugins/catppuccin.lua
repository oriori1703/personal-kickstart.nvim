local function gh(repo) return 'https://github.com/' .. repo end

-- [[ Colorscheme ]]
-- You can easily change to a different colorscheme.
-- Change the name of the colorscheme plugin below, and then
-- change the command under that to load whatever the name of that colorscheme is.
--
-- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
vim.pack.add { { src = gh 'catppuccin/nvim', name = 'catppuccin' } }
require('catppuccin').setup {}

-- Load the colorscheme here.
-- Like many other themes, this one has different styles, and you could load
-- any other, such as 'catppuccin-mocha', 'catppuccin-latte', or 'catppuccin-frappe'.
vim.cmd.colorscheme 'catppuccin-nvim'

-- vim: ts=2 sts=2 sw=2 et
