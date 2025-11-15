--- @module 'lazy'
--- @type LazySpec
return {
  'A7Lavinraj/fyler.nvim',
  dependencies = {
    {
      'mini.nvim',
      enabled = vim.g.have_nerd_font,
      config = function() require('mini.icons').setup {} end,
    },
  },
  --- @type FylerSetup
  opts = {},
  keys = {
    { '\\', function() require('fyler').toggle { kind = 'split_left_most' } end, desc = 'File Explorer' },
  },
}
