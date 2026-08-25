-- [[ Intro to `vim.pack` ]]
-- `vim.pack` is a new plugin manager built into Neovim,
--  which provides a Lua interface for installing and managing plugins.
--
--  See `:help vim.pack`, `:help vim.pack-examples` or the
--  excellent blog post from the creator of vim.pack and mini.nvim:
--  https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
--
--  To inspect plugin state and pending updates, run
--    :lua vim.pack.update(nil, { offline = true })
--
--  To update plugins, run
--    :lua vim.pack.update()
--
--
--  Throughout the rest of the config there will be examples
--  of how to install and configure plugins using `vim.pack`.
--
--  In this section we set up some autocommands to run build
--  steps for certain plugins after they are installed or updated.

-- Backfill Neovim 0.13's `:packupdate` command. User commands must start with
-- an uppercase letter, so the compatibility command is `:PackUpdate`.
local function get_plugin_names(skip_active)
  return vim
    .iter(vim.pack.get(nil, { info = false }))
    :filter(function(plugin) return not (skip_active and plugin.active) end)
    :map(function(plugin) return plugin.spec.name end)
    :totable()
end

local function verify_plugin_list(plugins)
  local installed = get_plugin_names()
  local not_found = vim.tbl_filter(function(name) return not vim.tbl_contains(installed, name) end, plugins)
  if #not_found > 0 then
    local msg = ('E5807: Plugin not installed: %s'):format(table.concat(not_found, ', '))
    vim.api.nvim_echo({ { msg, 'ErrorMsg' } }, true, { err = true })
    return false
  end
  return true
end

local function packupdate(opts)
  local offline = false
  local target
  local plugins = {}

  for _, arg in ipairs(opts.fargs) do
    if not vim.startswith(arg, '++') then
      plugins[#plugins + 1] = arg
    elseif arg == '++offline' then
      offline = true
    elseif arg == '++lockfile' then
      target = 'lockfile'
    else
      vim.api.nvim_echo({ { 'E474: Invalid argument', 'ErrorMsg' } }, true, { err = true })
      return
    end
  end

  if verify_plugin_list(plugins) then vim.pack.update(#plugins > 0 and plugins or nil, { force = opts.bang, offline = offline, target = target }) end
end

local function packupdate_complete(pattern)
  if vim.startswith(pattern, '++') then return { '++lockfile', '++offline' } end
  return get_plugin_names()
end

vim.api.nvim_create_user_command('PackUpdate', packupdate, {
  bang = true,
  nargs = '*',
  complete = packupdate_complete,
  desc = 'Update plugins managed by vim.pack',
})

local function packdel(opts)
  local all = false
  local plugins = {}

  for _, arg in ipairs(opts.fargs) do
    if not vim.startswith(arg, '++') then
      plugins[#plugins + 1] = arg
    elseif arg == '++all' then
      all = true
    else
      vim.api.nvim_echo({ { 'E474: Invalid argument', 'ErrorMsg' } }, true, { err = true })
      return
    end
  end

  if all then
    if #plugins > 0 then
      local msg = 'E5811: Cannot specify plugin names when using ++all'
      vim.api.nvim_echo({ { msg, 'ErrorMsg' } }, true, { err = true })
      return
    end
    plugins = get_plugin_names(not opts.bang)
  end

  if all or verify_plugin_list(plugins) then vim.pack.del(plugins, { force = opts.bang }) end
end

local function packdel_complete(pattern, line)
  local cmd = vim.api.nvim_parse_cmd(line, {})
  if #cmd.args == 1 and vim.startswith(pattern, '++') then return { '++all' } end
  if vim.tbl_contains(cmd.args, '++all') then return {} end
  return get_plugin_names(not cmd.bang)
end

vim.api.nvim_create_user_command('PackDel', packdel, {
  bang = true,
  nargs = '*',
  complete = packdel_complete,
  desc = 'Delete plugins managed by vim.pack',
})

local function run_build(name, cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd }):wait()
  if result.code ~= 0 then
    local stderr = result.stderr or ''
    local stdout = result.stdout or ''
    local output = stderr ~= '' and stderr or stdout
    if output == '' then output = 'No output from build command.' end
    vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
  end
end

-- This autocommand runs after a plugin is installed or updated and
--  runs the appropriate build command for that plugin if necessary.
--
-- See `:help vim.pack-events`
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name = ev.data.spec.name
    local kind = ev.data.kind
    if kind ~= 'install' and kind ~= 'update' then return end

    if name == 'LuaSnip' then
      if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
      return
    end

    if name == 'nvim-treesitter' then
      if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
      vim.cmd 'TSUpdate'
      return
    end

    if name == 'lua-json5' and vim.fn.executable 'cargo' == 1 then
      run_build(name, { './install.sh' }, ev.data.path)
      return
    end
  end,
})

-- vim: ts=2 sts=2 sw=2 et
