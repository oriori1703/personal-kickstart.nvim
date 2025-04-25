return {
  'obsidian-nvim/obsidian.nvim',
  version = '*',
  lazy = true,
  -- ft = 'markdown',
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  event = {
    'BufReadPre ' .. vim.fn.expand '~/Documents/vaults/*.md',
    'BufNewFile ' .. vim.fn.expand '~/Documents/vaults/*.md',
  },
  dependencies = {
    -- Required.
    'nvim-lua/plenary.nvim',
    -- Optional
    'folke/snacks.nvim',
  },
  ---@module 'obsidian'
  ---@type obsidian.config.ClientOpts
  ---@diagnostic disable-next-line: missing-fields
  opts = {
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
    ui = { enable = false },
  },
}
