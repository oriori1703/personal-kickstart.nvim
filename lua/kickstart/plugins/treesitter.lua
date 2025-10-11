return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter-intro`
    config = function()
      ---@param buf integer
      ---@param language string
      ---@return boolean
      local function treesitter_attach(buf, language)
        -- check if parser exists before starting highlighter
        if not vim.treesitter.language.add(language) then
          return false
        end
        -- enables syntax highlighting and other treesitter features
        vim.treesitter.start(buf, language)

        -- enables treesitter based folds
        -- for more info on folds see `:help folds`
        -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

        -- enables treesitter based indentation
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        return true
      end

      local available_parsers = require('nvim-treesitter.config').get_available()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match
          local language = vim.treesitter.language.get_lang(filetype)
          if not language then
            return
          end

          if not (treesitter_attach(buf, language) or vim.tbl_contains(available_parsers, language)) then
            return
          end

          -- automaically install parser for missing languages
          -- attempt to install even if it is available accoring to `vim.treesitter.langauge.add()`,
          -- to ensure the latest version is installed using `nvim-treesitter`, instead of the outdated vendored parser
          if not vim.tbl_contains(require('nvim-treesitter.config').get_installed 'parsers', language) then
            -- attempt to start highlighter after installing missing language
            require('nvim-treesitter.install').install(language):await(function() treesitter_attach(buf, language) end)
          end
        end,
      })

      -- ensure basic parser are installed
      local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
      require('nvim-treesitter').install(parsers)
    end,
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
}
-- vim: ts=2 sts=2 sw=2 et
