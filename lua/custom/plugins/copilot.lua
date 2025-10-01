--- @module 'lazy'
--- @type LazySpec
return {
  'folke/sidekick.nvim',
  ---@module "sidekick"
  ---@type sidekick.Config
  opts = {
    cli = { mux = { backend = 'tmux', enabled = true } },
  },
  keys = {
    {
      '<tab>',
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require('sidekick').nes_jump_or_apply() then
          return '<Tab>' -- fallback to normal tab
        end
      end,
      expr = true,
      desc = 'Goto/Apply Next Edit Suggestion',
    },
    {
      '<c-.>',
      function() require('sidekick.cli').focus() end,
      mode = { 'n', 'x', 'i', 't' },
      desc = 'Sidekick Switch Focus',
    },
    {
      '<leader>aa',
      function() require('sidekick.cli').toggle { focus = true } end,
      desc = 'Sidekick Toggle CLI',
      mode = { 'n', 'v' },
    },
    {
      '<leader>ao',
      function() require('sidekick.cli').toggle { name = 'opencode', focus = true } end,
      desc = 'Sidekick OpenCode Toggle',
      mode = { 'n', 'v' },
    },
    {
      '<leader>ap',
      function() require('sidekick.cli').select_prompt() end,
      desc = 'Sidekick Ask Prompt',
      mode = { 'n', 'v' },
    },
  },
  dependencies = {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    --- @module 'copilot'
    --- @type CopilotConfig
    opts = { --- @diagnostic disable-line: missing-fields
      suggestion = { enable = false }, --- @diagnostic disable-line: missing-fields
      panel = { enabled = false }, --- @diagnostic disable-line: missing-fields
      filetypes = { markdown = true, help = true }, -- override the default for markdown
    },
  },
}
