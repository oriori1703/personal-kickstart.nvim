local function gh(repo) return 'https://github.com/' .. repo end

-- [[ Snippet Engine ]]

-- NOTE: You can also specify plugin using a version range for its git tag.
--  See `:help vim.version.range()` for more info
vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
require('luasnip').setup {}

-- `friendly-snippets` contains a variety of premade snippets.
--    See the README about individual language/framework/plugin snippets:
--    https://github.com/rafamadriz/friendly-snippets

vim.pack.add { gh 'rafamadriz/friendly-snippets' }
require('luasnip.loaders.from_vscode').lazy_load()

-- [[ Autocomplete Engine ]]
vim.pack.add {
  { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' },
  gh 'folke/lazydev.nvim',
  gh 'fang2hou/blink-copilot',
}
require('blink.cmp').setup {
  keymap = {
    -- 'default' (recommended) for mappings similar to built-in completions
    --   <c-y> to accept ([y]es) the completion.
    --    This will auto-import if your LSP supports it.
    --    This will expand snippets if the LSP sent a snippet.
    -- 'super-tab' for tab to accept
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- For an understanding of why the 'default' preset is recommended,
    -- you will need to read `:help ins-completion`
    --
    -- No, but seriously. Please read `:help ins-completion`, it is really good!
    --
    -- All presets have the following mappings:
    -- <tab>/<s-tab>: move to right/left of your snippet expansion
    -- <c-space>: Open menu or open docs if already open
    -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
    -- <c-e>: Hide menu
    -- <c-k>: Toggle signature help
    --
    -- See `:help blink-cmp-config-keymap` for defining your own keymap
    preset = 'default',

    -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
    --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
  },

  appearance = {
    -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
    -- Adjusts spacing to ensure icons are aligned
    nerd_font_variant = 'mono',
  },

  completion = {
    -- By default, you may press `<c-space>` to show the documentation.
    -- Optionally, set `auto_show = true` to show the documentation after a delay.
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
  },

  sources = {
    default = {
      'lsp',
      'path',
      'snippets',
      'buffer',
      'copilot',
    },
    per_filetype = {
      lua = { inherit_defaults = true, 'lazydev' },
    },
    providers = {
      lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
      buffer = {
        -- Make buffer completions appear at the end.
        score_offset = -100,
        enabled = function()
          -- Filetypes for which buffer completions are enabled; add filetypes to extend:
          local enabled_filetypes = {
            'markdown',
            'text',
          }
          local filetype = vim.bo.filetype
          return vim.tbl_contains(enabled_filetypes, filetype)
        end,
      },
      copilot = {
        name = 'copilot',
        module = 'blink-copilot',
        score_offset = 100,
        async = true,
        opts = { max_completions = 1 },
      },
    },
  },

  snippets = { preset = 'luasnip' },

  -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
  -- which automatically downloads a prebuilt binary when enabled.
  --
  -- By default, we use the Lua implementation instead, but you may enable
  -- the rust implementation via `'prefer_rust_with_warning'`
  --
  -- See `:help blink-cmp-config-fuzzy` for more information
  fuzzy = { implementation = 'prefer_rust_with_warning' },

  -- Shows a signature help window while you type arguments for a function
  signature = { enabled = true },
}

-- vim: ts=2 sts=2 sw=2 et
