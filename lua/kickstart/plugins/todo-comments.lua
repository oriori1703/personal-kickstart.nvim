local function gh(repo) return 'https://github.com/' .. repo end

-- Highlight todo, notes, etc in comments
vim.pack.add { gh 'folke/todo-comments.nvim' }
require('todo-comments').setup { signs = false }

-- vim: ts=2 sts=2 sw=2 et
