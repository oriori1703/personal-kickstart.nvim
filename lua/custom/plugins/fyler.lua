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
    'folke/snacks.nvim',
  },
  --- @type FylerSetup
  opts = {
    hooks = { on_rename = function(src_path, dest_path) Snacks.rename.on_rename_file(src_path, dest_path) end },
  },
  keys = {
    { '\\', function() require('fyler').toggle { kind = 'split_left_most' } end, desc = 'File Explorer' },
  },
}
