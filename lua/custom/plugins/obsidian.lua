vim.pack.add {
  { src = 'https://github.com/obsidian-nvim/obsidian.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/folke/snacks.nvim',
}

require('obsidian').setup {
  workspaces = {
    {
      name = 'personal',
      path = '~/Documents/vaults/personal',
    },
    -- {
    --   name = 'work',
    --   path = '~/Documents/vaults/work',
    -- },
  },
  picker = { ---@diagnostic disable-line: missing-fields
    name = 'snacks.pick',
  },
  completion = { ---@diagnostic disable-line: missing-fields
    blink = true,
  },
  ---@diagnostic disable-next-line: missing-fields
  ui = { enable = false },
}
