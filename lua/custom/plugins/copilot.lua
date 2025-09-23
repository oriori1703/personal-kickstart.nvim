--- @module 'lazy'
--- @type LazySpec
return {
  'zbirenbaum/copilot.lua',
  dependencies = {
    {
      'copilotlsp-nvim/copilot-lsp',
      --- @module 'copilot-lsp'
      --- @type copilotlsp.config
      --- @diagnostic disable-next-line: missing-fields
      opts = {},
    },
  },
  cmd = 'Copilot',
  event = 'InsertEnter',
  --- @module 'copilot'
  --- @type CopilotConfig
  opts = { --- @diagnostic disable-line: missing-fields
    suggestion = { enable = false }, --- @diagnostic disable-line: missing-fields
    panel = { enabled = false }, --- @diagnostic disable-line: missing-fields
    filetypes = { markdown = true, help = true }, -- override the default for markdown
    nes = { --- @diagnostic disable-line: missing-fields
      enabled = true,
      auto_trigger = true,
      keymap = {
        accept_and_goto = '<leader>p',
        accept = false,
        dismiss = '<Esc>',
      },
    },
  },
}
