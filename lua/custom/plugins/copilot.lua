vim.pack.add {
  'https://github.com/zbirenbaum/copilot.lua',
  'https://github.com/copilotlsp-nvim/copilot-lsp',
}
require('copilot').setup {
  suggestion = { enable = false },
  panel = { enabled = false },
  filetypes = { markdown = true, help = true }, -- override the default for markdown
  nes = {
    enabled = true,
    auto_trigger = true,
    keymap = {
      accept_and_goto = '<leader>p',
      accept = false,
      dismiss = '<Esc>',
    },
  },
}
