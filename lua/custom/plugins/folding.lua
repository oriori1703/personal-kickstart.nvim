-- Makes folding look modern and keep high performance
return {
  'chrisgrieser/nvim-origami',
  event = 'VeryLazy',
  ---@module 'origami'
  ---@type Origami.config
  opts = {}, -- needed even when using default config

  -- recommended: disable vim's auto-folding
  init = function()
    vim.opt.foldlevel = 99
    vim.opt.foldlevelstart = 99
  end,
}
