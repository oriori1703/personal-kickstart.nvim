return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter-intro`
    config = function()
      local parsers = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        'smali',
        'java',
        'python',
        'rust',
        'go',
        'regex',
        'latex',
        'yaml',
      }
      require('nvim-treesitter').install(parsers)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = parsers,
        callback = function(args)
          local fname = vim.api.nvim_buf_get_name(args.buf)
          if fname:match 'sigma%.yaml$' then
            vim.treesitter.query.set(
              'yaml',
              'injections',
              [[
              ; inherits: yaml
              (
               (block_mapping_pair
                 key: (flow_node) @key
                 value: [
                         (flow_node [
                          (plain_scalar
                           (string_scalar)@injection.content)
                          (single_quote_scalar)@injection.content
                          (double_quote_scalar) @injection.content
                          ])
                         (block_node
                           (block_scalar)
                           @injection.content)
                        ])
               (#eq? @key "signature")
               (#set! injection.language "regex" @injection.content)
              )
              ]]
            )
          end
          -- syntax highlighting, provided by Neovim
          vim.treesitter.start()

          -- folds, provided by Neovim
          -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

          -- indentation, provided by nvim-treesitter
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
}
-- vim: ts=2 sts=2 sw=2 et
