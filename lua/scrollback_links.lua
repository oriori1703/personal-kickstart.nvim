-- OSC 8 navigation for static VT scrollback snapshots rendered by AnsiColorize.

---Terminal position: 1-based buffer line, 0-based screen-cell column.
---@alias scrollback_links.TermPosition { [1]: integer, [2]: integer }
---Extmark position: 0-based buffer line and UTF-8 byte column.
---@alias scrollback_links.BytePosition { [1]: integer, [2]: integer }

---@class scrollback_links.Request
---@field uri string Empty for a closing OSC 8 sequence.
---@field after integer 1-based byte offset after the sequence in the raw snapshot.
---@field text? string Visible label up to the next OSC 8 sequence.

---@class scrollback_links.ActiveLink
---@field uri string
---@field cursor scrollback_links.TermPosition
---@field text? string

---@class scrollback_links.PendingLink
---@field start scrollback_links.ActiveLink
---@field finish scrollback_links.TermPosition Exclusive end, subject to right-margin ambiguity.

local M = {}
local ns = vim.api.nvim_create_namespace 'scrollback_links'

-- Terminal columns count screen cells; extmarks count UTF-8 bytes.
---@param line string
---@param column integer 0-based screen-cell column.
---@return integer byte 0-based UTF-8 byte column.
local function byte_column(line, column)
  local byte, cells = 0, 0
  while byte < #line and cells < column do
    local char = vim.fn.matchstr(line, '.', byte)
    local width = vim.fn.strdisplaywidth(char, cells)
    if cells + width > column then break end
    byte, cells = byte + #char, cells + width
  end
  return byte
end

---@param text string
---@return string
local function plain(text) return (text:gsub('\27%][^\7\27]*[\7\27]\\?', ''):gsub('\27%[[0-?]*[ -/]*[@-~]', ''):gsub('\r?\n', '')) end

-- Keep the original labels only to disambiguate the terminal's right margin:
-- its cursor stays on the last glyph both before and after printing that glyph.
---@param raw string
---@return scrollback_links.Request[]
local function requests(raw)
  ---@type scrollback_links.Request[]
  local result = {}
  for first, uri, after in raw:gmatch '()\27%]8;[^;]*;([^\7\27]*)[\7\27]\\?()' do
    if #result > 0 and result[#result].uri ~= '' then result[#result].text = plain(raw:sub(result[#result].after, first - 1)) end
    result[#result + 1] = { uri = uri, after = after }
  end
  return result
end

---@param buf integer
---@param start scrollback_links.ActiveLink
---@param finish scrollback_links.TermPosition
---@param width integer Terminal width in screen cells.
---@return boolean? complete True if handled; nil if rendered text is not yet available.
local function add_link(buf, start, finish, width)
  if start.cursor[1] < 1 or finish[1] < start.cursor[1] then return true end
  local offset = start.cursor[1] - 1
  local lines = vim.api.nvim_buf_get_lines(buf, offset, finish[1], false)
  local starts = { start.cursor }
  local finishes = { finish }
  -- A wide glyph at the margin leaves the cursor two cells from the edge.
  if start.cursor[2] >= width - 2 then starts[#starts + 1] = { start.cursor[1] + 1, 0 } end
  if finish[2] >= width - 2 then finishes[#finishes + 1] = { finish[1], width } end

  ---@param first scrollback_links.TermPosition
  ---@param last scrollback_links.TermPosition
  ---@return scrollback_links.BytePosition? first
  ---@return scrollback_links.BytePosition? last
  ---@return string? text
  local function range(first, last)
    if not lines[first[1] - offset] or not lines[last[1] - offset] then return end
    local a = { first[1] - 1, byte_column(lines[first[1] - offset], first[2]) }
    local b = { last[1] - 1, byte_column(lines[last[1] - offset], last[2]) }
    if a[1] > b[1] or (a[1] == b[1] and a[2] >= b[2]) then return end
    local text = {}
    for row = a[1], b[1] do
      text[#text + 1] = lines[row + 1 - offset]:sub(row == a[1] and a[2] + 1 or 1, row == b[1] and b[2] or -1)
    end
    return a, b, table.concat(text)
  end

  ---@type scrollback_links.BytePosition?, scrollback_links.BytePosition?
  local first, last
  for _, a in ipairs(starts) do
    for _, b in ipairs(finishes) do
      local x, y, text = range(a, b)
      -- Matching also prevents attaching to blank/stale lines before refresh.
      if x and text == start.text then
        first, last = x, y
      end
    end
  end
  if first and last then
    vim.api.nvim_buf_set_extmark(buf, ns, first[1], first[2], {
      end_row = last[1],
      end_col = last[2],
      url = start.uri,
      hl_group = 'Underlined',
    })
    return true
  end
end

---@param uri string
---@return string target
---@return integer? line
---@return integer? column 1-based byte column.
local function file_location(uri)
  local scheme, rest = uri:match '^([%a][%w+.-]*):(.*)$'
  -- A bare filename followed by :195 can look like a URI scheme.
  if scheme and scheme ~= 'file' and not (rest and (rest:match '^%d+$' or rest:match '^%d+:%d+$')) then return uri end
  local target = scheme == 'file' and vim.uri_to_fname(uri) or uri
  -- Prefer existing literal paths; file: URIs use encoding for literal #/colon.
  if scheme ~= 'file' and vim.fn.filereadable(target) == 1 then return target end
  -- Parse before decoding so an encoded # or colon remains part of a filename.
  local path, line, column = uri:match '^(.-):(%d+):(%d+)$'
  if not path then
    path, line = uri:match '^(.-)#L(%d+)$'
  end
  if not path then
    path, line = uri:match '^(.-):(%d+)$'
  end
  local number = tonumber(line)
  local col = tonumber(column)
  if path and path ~= '' and number and number > 0 and (not col or col > 0) then return scheme == 'file' and vim.uri_to_fname(path) or path, number, col end
  return target
end

---@param buf integer Buffer containing the raw snapshot, before nvim_open_term().
function M.attach(buf)
  local raw = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  local expected = requests(raw)
  local index = 0
  ---@type scrollback_links.ActiveLink?
  local active
  local width = vim.api.nvim_win_get_width(0)
  ---@type scrollback_links.PendingLink[]
  local pending = {}
  local scheduled = false
  local function flush_later()
    if scheduled then return end
    scheduled = true
    vim.schedule(function()
      scheduled = false
      if not vim.api.nvim_buf_is_valid(buf) then return end
      ---@type scrollback_links.PendingLink[]
      local remaining = {}
      for _, link in ipairs(pending) do
        if not add_link(buf, link.start, link.finish, width) then remaining[#remaining + 1] = link end
      end
      pending = remaining
    end)
  end
  -- TermRequest can precede the refresh that writes rendered text to the buffer.
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if #pending > 0 then flush_later() end
    end,
  })
  vim.api.nvim_create_autocmd('TermRequest', {
    buffer = buf,
    callback = function(event)
      ---@type vim.event.termrequest.data
      local data = event.data
      local uri = data.sequence:match '^\27%]8;[^;]*;(.*)$'
      if uri == nil then return end
      index = index + 1
      if active then
        pending[#pending + 1] = { start = active, finish = data.cursor }
        flush_later()
      end
      active = uri ~= '' and { uri = uri, cursor = data.cursor, text = (expected[index] or {}).text } or nil
      expected[index] = nil
    end,
  })

  ---@param key string
  local function open_link(key)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { row, col }, { row, col }, { details = true, overlap = true })
    for _, mark in ipairs(marks) do
      local details = mark[4]
      -- Extmark queries also return a range at its exclusive end position.
      if details and details.url and details.end_row and details.end_col and (row < details.end_row or col < details.end_col) then
        local target, line, column = file_location(details.url)
        -- :edit still expands special filename characters such as # and %.
        vim.cmd.edit { args = { vim.fn.fnameescape(target) } }
        if key == 'gF' and line then vim.api.nvim_win_set_cursor(0, { math.min(line, vim.api.nvim_buf_line_count(0)), (column or 1) - 1 }) end
        return
      end
    end
    vim.cmd.normal { args = { tostring(vim.v.count1) .. key }, bang = true }
  end
  for _, key in ipairs { 'gf', 'gF' } do
    vim.keymap.set('n', key, function() open_link(key) end, { buffer = buf, desc = 'Edit scrollback link target' })
  end
end

return M
