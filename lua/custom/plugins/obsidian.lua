vim.pack.add {
  { src = 'https://github.com/obsidian-nvim/obsidian.nvim', version = vim.version.range '*' },
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
}

require('render-markdown').setup {
  enabled = false,
  completions = { lsp = { enabled = true } },
}

require('obsidian').setup {
  legacy_commands = false,
  workspaces = {
    {
      name = 'personal',
      path = '~/Documents/vaults/personal',
    },
    {
      name = 'work',
      path = '~/Documents/vaults/work',
    },
  },
  picker = {
    name = 'snacks.picker',
  },
  ---@diagnostic disable-next-line: missing-fields
  ui = { enable = false },
}
