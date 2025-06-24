vim.pack.add { 'https://github.com/rachartier/tiny-inline-diagnostic.nvim' }

require('tiny-inline-diagnostic').setup {
  options = {
    show_source = {
      if_many = true,
    },
    multilines = {
      enabled = true,
    },
  },
}
vim.diagnostic.config { virtual_text = false } -- Disable Neovim's default virtual text diagnostics
