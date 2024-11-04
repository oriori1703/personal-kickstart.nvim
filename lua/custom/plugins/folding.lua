-- Makes folding look modern and keep high performance
vim.pack.add {
  'https://github.com/kevinhwang91/nvim-ufo',
  'https://github.com/kevinhwang91/promise-async',
}
vim.opt.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.opt.foldlevelstart = 99
require('ufo').setup {}
