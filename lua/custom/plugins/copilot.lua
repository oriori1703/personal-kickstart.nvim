vim.pack.add {
  'https://github.com/folke/sidekick.nvim',
  'https://github.com/zbirenbaum/copilot.lua',
}

require('copilot').setup {
  suggestion = { enable = false },
  panel = { enabled = false },
  filetypes = { markdown = true, help = true },
}

require('sidekick').setup {
  cli = { mux = { backend = 'tmux', enabled = true } },
}

vim.keymap.set('n', '<tab>', function()
  if not require('sidekick').nes_jump_or_apply() then return '<Tab>' end
end, { expr = true, desc = 'Goto/Apply Next Edit Suggestion' })
vim.keymap.set({ 'n', 'x', 'i', 't' }, '<c-.>', function() require('sidekick.cli').focus() end, { desc = 'Sidekick Switch Focus' })
vim.keymap.set({ 'n', 'v' }, '<leader>aa', function() require('sidekick.cli').toggle { focus = true } end, { desc = 'Sidekick Toggle CLI' })
vim.keymap.set(
  { 'n', 'v' },
  '<leader>ao',
  function() require('sidekick.cli').toggle { name = 'opencode', focus = true } end,
  { desc = 'Sidekick OpenCode Toggle' }
)
vim.keymap.set({ 'n', 'v' }, '<leader>ap', function() require('sidekick.cli').select_prompt() end, { desc = 'Sidekick Ask Prompt' })
