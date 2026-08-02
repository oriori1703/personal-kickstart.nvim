--- Inlay Hint Actions Plugin
--- Based on neovim/neovim PR #36219 by Davidyz
--- https://github.com/neovim/neovim/pull/36219
---
--- This is a standalone implementation of inlay hint actions that will be easy
--- to migrate to the official vim.lsp.inlay_hint.action() once it lands in Neovim core.
---
--- Supported actions:
---   - 'textEdits': Insert text edits from inlay hints into the buffer
---   - 'location': Jump to type/parameter definition location
---   - 'hover': Show hover info for locations in hints
---   - 'tooltip': Show comprehensive tooltip with hint info, locations, commands
---   - 'command': Execute LSP workspace commands from hint label parts
---
--- Usage:
---   local actions = require('inlay_hint_actions')
---   actions.action('textEdits')  -- Apply text edits at cursor
---   actions.action('location')   -- Jump to location
---   actions.action('tooltip')    -- Show tooltip window
---
--- Migration path (when vim.lsp.inlay_hint.action() is available in Neovim core):
---   1. Delete this file
---   2. Replace: require('inlay_hint_actions').action -> vim.lsp.inlay_hint.action
---   3. Done!

local util = require 'vim.lsp.util'
local api = vim.api
local fn = vim.fn

local M = {}

--- @class (private) inlay_hint_actions.hint_label
--- @field hint lsp.InlayHint
--- @field label lsp.InlayHintLabelPart

--- Turn an inlay hint object into the visible text, merging any label parts.
--- Paddings can be optionally included.
--- @param hint lsp.InlayHint
--- @param with_padding boolean?
--- @return string
local function get_label_text(hint, with_padding)
  --- @type string?
  local label
  if type(hint.label) == 'string' then
    label = tostring(hint.label)
  elseif vim.islist(hint.label) then
    ---@type string
    label = vim
      .iter(hint.label)
      :map(
        --- @param part lsp.InlayHintLabelPart
        function(part) return part.value end
      )
      :join ''
  end

  assert(label ~= nil, 'Failed to extract the label value from the inlay hint')

  if with_padding then
    if hint.paddingLeft then label = ' ' .. label end
    if hint.paddingRight then label = label .. ' ' end
  end

  return label
end

--- A wrapper of `vim.ui.select` that skips the menu when there's only one item.
--- @generic T
--- @param items T[] Arbitrary items
--- @param opts vim.ui.select.Opts Additional options
--- @param on_choice fun(item: T|nil, idx: integer|nil)
local function do_or_select(items, opts, on_choice)
  if #items == 0 then return error 'Empty items!' end
  if #items == 1 then return on_choice(items[1], 1) end
  return vim.ui.select(items, opts, on_choice)
end

--- @param path string
--- @param base string?
--- @return string
local function cleanup_path(path, base)
  ---@type string?
  local result = nil
  if base then
    -- relative to `base`
    result = vim.fs.relpath(base, path)
  end
  if result == nil then result = fn.fnamemodify(path, ':p:~') end
  return result
end

--- Build the range from normal or visual mode based on cursor position.
--- @return vim.Range
local function make_range()
  local bufnr = api.nvim_get_current_buf()
  local winid = fn.bufwinid(bufnr)
  local mode = fn.mode()

  if mode == 'n' then
    local cursor = api.nvim_win_get_cursor(winid)
    -- Include the hints on either side of the cursor.
    local row, col = cursor[1] - 1, cursor[2]
    return vim.range(bufnr, row, col, row, col + 1)
  end

  local start_pos = fn.getpos 'v'
  local end_pos = fn.getpos '.'
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    --- @type [integer, integer, integer, integer]
    start_pos, end_pos = end_pos, start_pos
  end
  local start_row, start_col = start_pos[2] - 1, start_pos[3] - 1
  local end_row, end_col = end_pos[2] - 1, end_pos[3]

  if mode == 'V' or mode == 'Vs' then
    start_col = 0
    end_row = end_row + 1
    end_col = 0
  end
  return vim.range(bufnr, start_row, start_col, end_row, end_col)
end

--- Append `new_label` to `labels` if there are no duplicates.
---@param labels inlay_hint_actions.hint_label[]
---@param new_label inlay_hint_actions.hint_label
---@param by_attribute ('location'|'command'|'tooltip')[]|nil When provided, only check for these attributes (and `value`) for equality
local function add_new_label(labels, new_label, by_attribute)
  if
    vim.iter(labels):any(
      ---@param existing_label inlay_hint_actions.hint_label
      function(existing_label)
        -- Check for duplications with existing hint_labels
        if by_attribute then
          -- Check for concerned attributes
          return vim.iter(by_attribute):all(
            function(attr) return existing_label.label.value == new_label.label.value and vim.deep_equal(existing_label.label[attr], new_label.label[attr]) end
          )
        else
          -- Check the entire label
          return vim.deep_equal(existing_label.label, new_label.label)
        end
      end
    )
  then
    return
  end
  table.insert(labels, new_label)
end

--- Return a non-empty list of hint labels, or `nil` if not found.
--- @param hint lsp.InlayHint
--- @param needed_fields ("location"|"command"|"tooltip")[]
--- @return inlay_hint_actions.hint_label[]?
local function get_hint_labels(hint, needed_fields)
  --- @type inlay_hint_actions.hint_label[]
  local hint_labels = {}

  if type(hint.label) == 'table' and #hint.label > 0 then
    vim.iter(hint.label):each(
      --- @param label lsp.InlayHintLabelPart
      function(label)
        if vim.iter(needed_fields):any(function(field_name) return label[field_name] ~= nil end) then
          add_new_label(hint_labels, { hint = hint, label = label }, needed_fields)
        end
      end
    )
  end

  if #hint_labels > 0 then return hint_labels end
end

--- The built-in action handlers.
--- @type table<inlay_hint_actions.name, inlay_hint_actions.handler>
local action_handlers = {
  textEdits = function(hints, ctx, on_done)
    ---@type lsp.InlayHint[]
    local valid_hints = vim
      .iter(hints)
      :filter(
        --- @param hint lsp.InlayHint
        function(hint)
          -- only keep those that have text edits.
          return hint ~= nil and hint.textEdits ~= nil and not vim.tbl_isempty(hint.textEdits)
        end
      )
      :totable()
    --- @type lsp.TextEdit[]
    local text_edits = vim
      .iter(valid_hints)
      :map(
        --- @param hint lsp.InlayHint
        function(hint) return hint.textEdits end
      )
      :flatten(1)
      :totable()
    if #text_edits == 0 then return false end
    vim.schedule(function()
      util.apply_text_edits(text_edits, ctx.buf, ctx.client.offset_encoding)
      if on_done then on_done { buf = ctx.buf, client = ctx.client } end
    end)
    return true
  end,
  location = function(hints, ctx, on_done)
    --- @type inlay_hint_actions.hint_label[]
    local hint_labels = {}

    vim.iter(hints):each(
      --- @param item lsp.InlayHint
      function(item)
        if type(item.label) == 'table' and #item.label > 0 then
          local labels_from_this = get_hint_labels(item, { 'location' })
          if labels_from_this then vim.list_extend(hint_labels, labels_from_this) end
        end
      end
    )

    if vim.tbl_isempty(hint_labels) then return false end

    do_or_select(
      vim
        .iter(hint_labels)
        :map(
          --- @param loc inlay_hint_actions.hint_label
          function(loc)
            local label = loc.label
            return string.format(
              '%s\t%s:%d',
              label.value,
              cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir),
              label.location.range.start.line
            )
          end
        )
        :totable(),
      { prompt = 'Location to jump to' },
      function(_, idx)
        if idx == nil then
          -- `vim.ui.select` was cancelled
          if on_done then on_done { buf = ctx.buf } end
          return
        end
        util.show_document(hint_labels[idx].label.location, ctx.client.offset_encoding, { reuse_win = true, focus = true })

        if on_done then on_done { buf = api.nvim_get_current_buf(), client = ctx.client } end
      end
    )

    return true
  end,

  hover = function(hints, ctx, on_done)
    if #hints == 0 then return false end
    if #hints ~= 1 then
      vim.schedule(function() vim.notify('inlay_hint_actions.action("hover") only supports showing hover for a single inlay hint.', vim.log.levels.WARN) end)
    end
    local hint = assert(hints[1])
    local hint_labels = get_hint_labels(hint, { 'location' })
    if hint_labels == nil then return false end

    ---@type string[]
    local lines = {}

    --- Go through the labels to build the content of the hover
    ---@param idx integer?
    ---@param item inlay_hint_actions.hint_label?
    local function get_hover(idx, item)
      if idx == nil or item == nil then
        -- all locations have been processed
        -- open the hover window
        if #lines == 0 then lines = { 'Empty' } end
        local float_buf, _ = util.open_floating_preview(lines, 'markdown')
        if on_done then on_done { client = ctx.client, buf = float_buf } end
        return
      end

      -- `get_hint_labels` makes sure `item.label` has location attribute
      local label_loc = assert(item.label.location)
      ---@type lsp.HoverParams
      local hover_param = {
        textDocument = { uri = label_loc.uri },
        position = label_loc.range.start,
      }
      ctx.client:request(
        'textDocument/hover',
        hover_param,
        ---@param result lsp.Hover?
        function(_, result, _, _)
          if result then
            local md_lines = util.convert_input_to_markdown_lines(result.contents)
            if #md_lines > 0 then
              if #lines > 0 then
                -- Blank line between label parts
                lines[#lines + 1] = ''
              end
              lines[#lines + 1] = string.format('# `%s`', item.label.value)
              vim.list_extend(lines, md_lines)
            end
          end
          get_hover(next(hint_labels, idx))
        end,
        ctx.buf
      )
    end

    get_hover(next(hint_labels))
    return true
  end,

  tooltip = function(hints, ctx, on_done)
    if #hints == 0 then return false end
    if #hints ~= 1 then
      vim.schedule(
        function() vim.notify('inlay_hint_actions.action("tooltip") only supports showing tooltips for a single inlay hint.', vim.log.levels.WARN) end
      )
    end

    local hint = assert(hints[1])
    local hint_labels = get_hint_labels(hint, { 'location', 'command' })

    -- The level 1 heading is the full hint object
    local lines = { string.format('# `%s`', get_label_text(hint, false)), '' }

    if hint.tooltip then util.convert_input_to_markdown_lines(hint.tooltip, lines) end

    if hint_labels then
      vim.iter(hint_labels):each(
        --- @param hint_label inlay_hint_actions.hint_label
        function(hint_label)
          local label = hint_label.label
          lines[#lines + 1] = ''
          -- each of the level 2 headings is the text of a label part
          lines[#lines + 1] = string.format('## `%s`', label.value)
          lines[#lines + 1] = ''
          if label.tooltip then
            -- borrowed from `vim.lsp.buf.hover()`
            util.convert_input_to_markdown_lines(label.tooltip, lines)
          end
          if label.location then
            -- include the location in this label part
            lines[#lines + 1] =
              string.format('_Location_: `%s`:%d', cleanup_path(vim.uri_to_fname(label.location.uri), ctx.client.root_dir), label.location.range.start.line)
          end
          if label.command then
            -- include the command associated to this label part
            local command_line = string.format('_Command_: %s', label.command.title)
            if label.command.tooltip then command_line = command_line .. string.format(' (%s)', label.command.tooltip) end
            lines[#lines + 1] = command_line
          end
        end
      )
    end

    if #lines == 2 then
      -- No tooltip/command/location has been found. Skip this hint.
      return false
    end

    ---@type integer, integer
    local buf, _ = util.open_floating_preview(lines, 'markdown')

    if on_done then on_done { buf = buf, client = ctx.client } end
    return true
  end,

  command = function(hints, ctx, on_done)
    if #hints == 0 then return false end
    if #hints ~= 1 then
      vim.schedule(
        function() vim.notify('inlay_hint_actions.action("command") only supports showing commands for a single inlay hint.', vim.log.levels.WARN) end
      )
    end
    local hint_labels = get_hint_labels(assert(hints[1]), { 'command' })
    if hint_labels == nil or #hint_labels == 0 then
      -- no commands in this hint
      return false
    end

    do_or_select(
      vim
        .iter(hint_labels)
        :map(
          --- @param item inlay_hint_actions.hint_label
          function(item)
            local label = item.label
            local entry_line = string.format('%s: %s', label.value, assert(label.command).title)
            if label.tooltip then entry_line = entry_line .. string.format(' (%s)', label.tooltip) end
            return entry_line
          end
        )
        :totable(),
      { prompt = 'Command to execute' },
      function(_, idx)
        if idx == nil then
          -- `vim.ui.select` was cancelled
          if on_done then on_done { buf = ctx.buf } end
          return
        end
        ctx.client:request('workspace/executeCommand', hint_labels[idx].label.command, function(...)
          local default_handler = ctx.client.handlers['workspace/executeCommand'] or vim.lsp.handlers['workspace/executeCommand']
          if default_handler then default_handler(...) end
          if on_done then on_done { buf = api.nvim_get_current_buf(), client = ctx.client } end
        end, ctx.buf)
      end
    )

    return true
  end,
}

--- @alias inlay_hint_actions.name
---| 'textEdits' -- Insert texts into the buffer
---| 'command' -- See 'workspace/executeCommand'
---| 'location' -- Jump to the location (usually the definition of the identifier or type)
---| 'hover' -- Show a hover window of the symbols shown in the inlay hint
---| 'tooltip' -- Show a hover-like window, containing available tooltips, commands and locations

--- A built-in action name, or a custom handler.
--- @alias inlay_hint_actions.spec
---| inlay_hint_actions.name
---| inlay_hint_actions.handler

--- @class inlay_hint_actions.context
--- @inlinedoc
--- @field buf integer
--- @field client vim.lsp.Client

--- @class inlay_hint_actions.on_done.context
--- @inlinedoc
---
--- The buffer that ends up focused by the action. If the action opened or jumped to a new
--- buffer, this is that buffer; otherwise it's the buffer the action started from.
--- @field buf integer
---
--- The `vim.lsp.Client` used to invoke the action. `nil` when no action was invoked.
--- @field client? vim.lsp.Client

--- This should be called __exactly__ once in the action handler.
--- @alias inlay_hint_actions.on_done.callback fun(ctx: inlay_hint_actions.on_done.context)

--- @alias inlay_hint_actions.handler fun(hints: lsp.InlayHint[], ctx: inlay_hint_actions.context, on_done: inlay_hint_actions.on_done.callback?): boolean

--- @class inlay_hint_actions.Opts
--- @inlinedoc
--- Inlay hints (returned by `vim.lsp.inlay_hint.get()`) to take actions on.
--- When not specified:
---   - in |Normal-mode|, it uses hints on either side of the cursor.
---   - in |Visual-mode|, it uses hints inside the selected range.
--- @field hints? vim.lsp.inlay_hint.get.ret[]
---
--- A callback invoked exactly once (asynchronously) at the end of the action.
--- @field on_done? inlay_hint_actions.on_done.callback

--- Apply some actions provided by inlay hints in the selected range.
---
--- Example usage:
--- ```lua
--- vim.keymap.set(
---   { 'n', 'v' },
---   'grI',
---   function()
---     require('inlay_hint_actions').action('textEdits')
---   end,
---   { desc = 'Apply inlay hint textEdits' }
--- )
--- ```
---
--- @param action inlay_hint_actions.spec
--- Possible actions:
--- - `"textEdits"`: insert `textEdits` that comes with the inlay hints.
--- - `"location"`: jump to one of the locations associated with the inlay hints.
--- - `"command"`: execute one of the `lsp.Command`s that comes with the inlay hint.
--- - `"hover"`: if there are some locations associated with the inlay hint, show the hover
---   information of the identifiers at those locations.
--- - `"tooltip"`: show a hover-like window that contains the `tooltip`, available `command`s and
---   `location`s that comes with the inlay hint.
--- - a custom handler with 3 parameters:
---   - `hints`: `lsp.InlayHint[]` a list of inlay hints in the requested range.
---   - `ctx`: `{buf: integer, client: vim.lsp.Client}` the buffer on which the action is taken, and the LSP client that provides `hints`.
---   - `on_done`: `fun(ctx: {buf: integer, client?: vim.lsp.Client})` see `on_done` in {opts}.
---
---   The handler must return `true` if it handled the action (and then call `on_done` exactly
---   once when the action finishes), or `false` if `hints` did not contain what the action
---   needs, in which case the hints of the next available client are tried.
--- @param opts? inlay_hint_actions.Opts
function M.action(action, opts)
  vim.validate('action', action, function(val) return type(val) == 'function' or type(action_handlers[val]) == 'function' end, false)
  vim.validate('opts', opts, 'table', true)

  opts = opts or {}
  vim.validate('opts.on_done', opts.on_done, 'function', true)

  local action_handler = action
  if type(action) == 'string' then
    action_handler = action_handlers[action] --- @cast action_handler -inlay_hint_actions.name
  end

  local bufnr = api.nvim_get_current_buf()

  local on_done_called = false
  local on_done = opts.on_done
  if on_done then
    local original_on_done = on_done
    -- Decorate `on_done` to make sure it is only called once.
    ---@type inlay_hint_actions.on_done.callback
    on_done = function(...)
      assert(not on_done_called, '`on_done` should only be called once.')
      on_done_called = true
      return original_on_done(...)
    end
  end

  local hints = opts.hints
  if hints == nil then
    local range = make_range()
    hints = vim.lsp.inlay_hint.get {
      range = {
        -- In `M.on_inlayhint`,
        -- the inlay hints are stored by byte indices, not lsp positions (utf-*),
        -- so we can't use `vim.range.to_lsp`
        start = { line = range.start_row, character = range.start_col },
        ['end'] = { line = range.end_row, character = range.end_col },
      },
      bufnr = bufnr,
    }
  end
  --- Group inlay hints by clients.
  ---@type table<integer, lsp.InlayHint[]>
  local hints_by_clients = vim.defaulttable()

  vim.iter(hints):each(
    ---@param item vim.lsp.inlay_hint.get.ret
    function(item) table.insert(hints_by_clients[item.client_id], item.inlay_hint) end
  )

  local client_ids = vim.tbl_keys(hints_by_clients)
  -- `vim.tbl_keys` ordering is not deterministic; try clients in a stable order.
  table.sort(client_ids)

  ---@type vim.lsp.Client[]
  local clients = vim.iter(client_ids):map(function(cli_id) return vim.lsp.get_client_by_id(cli_id) end):totable()

  --- Iterate through `clients` and requests for inlay hints.
  --- If a client provides no inlay hint (`nil` or `{}`) for the given range, or the provided hints don't contain
  --- the attributes needed for the action, proceed to the next client. Otherwise, the action is
  --- successful. Terminate the iteration.
  --- @param idx? integer
  --- @param client? vim.lsp.Client
  local function do_action(idx, client)
    if idx == nil or client == nil or on_done_called then
      -- all clients have been consumed. Terminate the iteration.
      if on_done and not on_done_called then on_done { buf = api.nvim_get_current_buf() } end
      return
    end

    local _hints = hints_by_clients[client.id]

    if #_hints == 0 then
      -- no hints in the given range.
      return do_action(next(clients, idx))
    end

    local support_resolve = client:supports_method('inlayHint/resolve', bufnr)
    local action_ctx = { buf = bufnr, client = client }

    if not support_resolve then
      -- no need to resolve because the client doesn't support it.
      if not action_handler(_hints, action_ctx, on_done) then
        -- no actions invoked. proceed with the client.
        return do_action(next(clients, idx))
      else
        -- actions were taken. we're done with the actions.
        return
      end
    end

    --- NOTE: make async `inlayHint/resolve` requests in parallel

    -- Use `num_processed` to keep track of the number of resolved hints.
    -- When this equals `#hints`, it means we're ready to invoke the actions.
    --- @type integer
    local num_processed = 0

    for i, h in ipairs(_hints) do
      client:request('inlayHint/resolve', h, function(_, _result, _, _)
        if _result ~= nil and _hints[i] then _hints[i] = vim.tbl_deep_extend('force', _hints[i], _result) end
        num_processed = num_processed + 1

        if num_processed == #_hints then
          -- all hints have been resolved. we're now ready to invoke the action.
          if not action_handler(_hints, action_ctx, on_done) then
            return do_action(next(clients, idx))
          else
            -- Actions were taken. we're done with the actions.
            return
          end
        end
      end, bufnr)
    end
  end

  do_action(next(clients))
end

return M
