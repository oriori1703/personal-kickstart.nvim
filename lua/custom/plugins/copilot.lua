vim.pack.add { 'https://github.com/zbirenbaum/copilot.lua' }
require('copilot').setup {
  suggestion = { enable = false },
  panel = { enabled = false },
  filetypes = { markdown = true }, -- override the default for markdown
}
