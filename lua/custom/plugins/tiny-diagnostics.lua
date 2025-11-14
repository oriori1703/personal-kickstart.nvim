--- @module 'lazy'
--- @type LazySpec
return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'VeryLazy',
  priority = 1000,
  config = function()
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
  end,
}
