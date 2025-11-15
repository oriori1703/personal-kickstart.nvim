vim.pack.add { 'https://github.com/A7Lavinraj/fyler.nvim' }

local fyler = require 'fyler'
fyler.setup {}
vim.keymap.set('n', '\\', function() fyler.toggle { kind = 'split_left_most' } end, { desc = 'File Explorer' })
