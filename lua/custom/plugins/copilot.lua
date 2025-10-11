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
    { '<c-.>', function() require('sidekick.cli').toggle() end, desc = 'Sidekick Toggle', mode = { 'n', 't', 'i', 'x' } },
    { '<leader>aa', function() require('sidekick.cli').toggle() end, desc = 'Sidekick Toggle CLI' },
    { '<leader>as', function() require('sidekick.cli').select() end, desc = 'Select CLI' },
    { '<leader>ad', function() require('sidekick.cli').close() end, desc = 'Detach a CLI Session' },
    { '<leader>at', function() require('sidekick.cli').send { msg = '{this}' } end, mode = { 'x', 'n' }, desc = 'Send This' },
    { '<leader>af', function() require('sidekick.cli').send { msg = '{file}' } end, desc = 'Send File' },
    { '<leader>av', function() require('sidekick.cli').send { msg = '{selection}' } end, mode = { 'x' }, desc = 'Send Visual Selection' },
    { '<leader>ap', function() require('sidekick.cli').prompt() end, mode = { 'n', 'x' }, desc = 'Sidekick Select Prompt' },
    { '<leader>ao', function() require('sidekick.cli').toggle { name = 'opencode', focus = true } end, desc = 'Sidekick Toggle Claude' },
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
