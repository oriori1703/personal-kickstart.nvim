return {
  'zbirenbaum/copilot.lua',
  cmd = 'Copilot',
  event = 'InsertEnter',
  opts = {
    suggestion = { enable = false },
    panel = { enabled = false },
    filetypes = { markdown = true }, -- override the default for markdown
  },
}
