-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/igorlfs/nvim-dap-view',
  'https://github.com/Joakker/lua-json5',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
  'https://github.com/mfussenegger/nvim-dap-python',
}

-- Basic debugging keymaps, feel free to change to your liking!
vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>b', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function()
  local dap = require 'dap'

  -- Search for an existing breakpoint on this line in this buffer
  ---@return dap.SourceBreakpoint bp that was either found, or an empty placeholder
  local function find_bp()
    local buf_bps = require('dap.breakpoints').get(vim.fn.bufnr())[vim.fn.bufnr()]
    ---@type dap.SourceBreakpoint
    for _, candidate in ipairs(buf_bps) do
      if candidate.line and candidate.line == vim.fn.line '.' then return candidate end
    end

    return { condition = '', logMessage = '', hitCondition = '', line = vim.fn.line '.' }
  end

  -- Elicit customization via a UI prompt
  ---@param bp dap.SourceBreakpoint a breakpoint
  local function customize_bp(bp)
    local props = {
      ['Condition'] = {
        value = bp.condition,
        setter = function(v) bp.condition = v end,
      },
      ['Hit Condition'] = {
        value = bp.hitCondition,
        setter = function(v) bp.hitCondition = v end,
      },
      ['Log Message'] = {
        value = bp.logMessage,
        setter = function(v) bp.logMessage = v end,
      },
    }
    local menu_options = {}
    for k, _ in pairs(props) do
      table.insert(menu_options, k)
    end
    vim.ui.select(menu_options, {
      prompt = 'Edit Breakpoint',
      format_item = function(item) return ('%s: %s'):format(item, props[item].value) end,
    }, function(choice)
      if choice == nil then
        -- User cancelled the selection
        return
      end
      props[choice].setter(vim.fn.input {
        prompt = ('[%s] '):format(choice),
        default = props[choice].value,
      })

      -- Set breakpoint for current line, with customizations (see h:dap.set_breakpoint())
      dap.set_breakpoint(bp.condition, bp.hitCondition, bp.logMessage)
    end)
  end

  customize_bp(find_bp())
end, { desc = 'Debug: Set Breakpoint' })

vim.keymap.set('n', '<Leader>lp', function() require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log point message: ') end, { desc = 'Debug: Set Logpoint' })
-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
vim.keymap.set('n', '<F7>', function() require('dap-view').toggle() end, { desc = 'Debug: See last session result.' })

local ok, json5 = pcall(require, 'json5')
if ok then require('dap.ext.vscode').json_decode = json5.parse end

require('mason-nvim-dap').setup {
  -- Makes a best effort to setup the various debuggers with
  -- reasonable debug configurations
  automatic_installation = { exclude = { 'python' } },

  -- You can provide additional configuration to the handlers,
  -- see mason-nvim-dap README for more information
  handlers = {},

  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = {
    -- Update this to ensure that you have the debuggers for the langs you want
    -- 'delve',
    -- 'python',
  },
}

-- Change breakpoint icons
vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
local breakpoint_icons = vim.g.have_nerd_font
    and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
  or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
for type, icon in pairs(breakpoint_icons) do
  local tp = 'Dap' .. type
  local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
  vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
end

require('dap-view').setup {
  virtual_text = { enabled = true },
  auto_toggle = 'keep_terminal',
}

-- Install golang specific config
-- require('dap-go').setup {
--   delve = {
--     -- On Windows delve must be run attached or it crashes.
--     -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
--     detached = vim.fn.has 'win32' == 0,
--   },
-- }
require('dap-python').setup 'uv'
