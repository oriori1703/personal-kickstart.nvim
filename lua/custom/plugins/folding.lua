-- Makes folding look modern and keep high performance
--- @module 'lazy'
--- @type LazySpec
return {
  'chrisgrieser/nvim-origami',
  event = 'VeryLazy',
  ---@module 'origami'
  ---@type Origami.config
  opts = {
    foldKeymaps = { setup = false },
    autoFold = { enabled = true, kinds = { 'imports' } },
  },

  -- recommended: disable vim's auto-folding
  init = function()
    vim.opt.foldlevel = 99
    vim.opt.foldlevelstart = 99
  end,
}
