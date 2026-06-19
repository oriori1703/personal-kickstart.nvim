vim.pack.add { 'https://github.com/A7Lavinraj/fyler.nvim' }

local fyler = require 'fyler'
fyler.setup {
  hooks = { on_rename = function(src_path, dest_path) Snacks.rename.on_rename_file(src_path, dest_path) end },
  integrations = { icon = 'mini_icons' },
  extensions = {
    git = { enabled = true },
  },
}
vim.keymap.set('n', '\\', function() fyler.toggle { kind = 'split_left_most' } end, { desc = 'File Explorer' })
