--- @module 'lazy'
--- @type LazySpec
return {
  'obsidian-nvim/obsidian.nvim',
  version = '*',
  lazy = true,
  -- ft = 'markdown',
  event = {
    'BufReadPre ' .. vim.fn.expand '~/Documents/vaults/*.md',
    'BufNewFile ' .. vim.fn.expand '~/Documents/vaults/*.md',
  },
  dependencies = {
    'saghen/blink.cmp',
    'folke/snacks.nvim',
  },
  ---@module 'obsidian'
  ---@type obsidian.config
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
    picker = {
      name = 'snacks.pick',
    },
    completion = {
      blink = true,
    },
    ui = { enable = false },
  },
}
