-- Load plugin modules in order.

require 'kickstart.plugins.guess-indent'
require 'kickstart.plugins.gitsigns'
require 'kickstart.plugins.which-key'
-- require 'kickstart.plugins.tokyonight'
require 'kickstart.plugins.todo-comments'
require 'kickstart.plugins.mini'
require 'kickstart.plugins.lspconfig'
require 'kickstart.plugins.conform'
require 'kickstart.plugins.blink-cmp'
require 'kickstart.plugins.treesitter'

-- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
-- init.lua. If you want these files, they are in the repository, so you can just download them and
-- place them in the correct locations.

-- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
--
--  Here are some example plugins that I've included in the Kickstart repository.
--  Uncomment any of the lines below to enable them (you will need to restart nvim).
--
require 'kickstart.plugins.debug'
require 'kickstart.plugins.indent_line'
require 'kickstart.plugins.lint'
require 'kickstart.plugins.autopairs'
require 'kickstart.plugins.neo-tree'

-- NOTE: You can add your own plugins, configuration, etc. in `lua/custom/plugins/*.lua`.
--
-- Load independent modules through the convenience loader:
require 'custom.plugins'
--
-- `custom.plugins` automatically loads files from that directory, but their
-- order is unspecified. If plugins depend on each other, keep them in the same
-- file and put their `vim.pack.add()` and `setup()` calls in the required order.
--
-- If separate modules need a specific order, require them explicitly instead:
-- require 'custom.plugins.colorscheme'
-- require 'custom.plugins.ui'
-- require 'custom.plugins.git'

-- vim: ts=2 sts=2 sw=2 et
