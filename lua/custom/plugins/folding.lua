-- Makes folding look modern and keep high performance
vim.pack.add { 'https://github.com/chrisgrieser/nvim-origami' }
require('origami').setup {
  foldKeymaps = { setup = false },
  autoFold = { enabled = true, kinds = { 'imports' } },
}

-- recommended: disable vim's auto-folding
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
