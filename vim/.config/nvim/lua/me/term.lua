local api = vim.api

local M = {}

local jobid = nil
local winid = nil


local function launch_term(cmd, opts)
  opts = opts or {}
  vim.cmd("belowright new")
  winid = vim.fn.win_getid()
  api.nvim_win_set_var(0, 'REPL', 1)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.buflisted = false
  vim.bo.swapfile = false
  opts = vim.tbl_extend('error', opts, {
    on_exit = function()
      jobid = nil
    end
  })
  jobid = vim.fn.termopen(cmd, opts)
end

local function close_term()
  if not jobid then
    return
  end
  vim.fn.jobstop(jobid)
  if api.nvim_win_is_valid(winid) then
    api.nvim_win_close(winid, true)
  end
  winid = nil
end

function M.toggle()
  if jobid then
    close_term()
  else
    launch_term(vim.fn.environ()['SHELL'] or 'sh')
  end
end


function M.run()
  local filepath = api.nvim_buf_get_name(0)
  close_term()
  launch_term(filepath)
end


function M.cr8_run_next()
  local bufnr = api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr)
  local tree = parser:parse()[1]
  local root = tree:root()
  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  lnum = lnum - 1
  local cursor_node = root:descendant_for_range(lnum, col, lnum, col)
  local parent = cursor_node:parent()
  while parent ~= nil do
    local type = parent:type()
    if type == "table" and parent:child_count() > 0 then
      local child = parent:child(1)
      if child:type() == "bare_key" then
        local name = vim.treesitter.get_node_text(child, bufnr)
        if name == "setup" or name == "teardown" then
          local cmd = {
            'cr8',
            'run-spec',
            api.nvim_buf_get_name(bufnr),
            'localhost:4200',
            '--action', name,
          }
          close_term()
          launch_term(cmd)
          return
        end
      end
    end
    parent = parent:parent()
  end
  local query = vim.treesitter.query.parse(vim.bo.filetype, [[
    ((table_array_element
      (bare_key) @element_name
      (#eq? @element_name "queries")
      (pair
        (bare_key) @property
        (string) @value
        (#eq? @property "name")
      )
     )
    )
  ]])
  local last = nil
  for id, node in query:iter_captures(root, bufnr, 0, lnum) do
    local capture = query.captures[id]
    if capture == "value" then
      last = node
    end
  end
  if last then
    local name = vim.treesitter.get_node_text(last, bufnr)
    local cmd = {
      'cr8',
      'run-spec',
      api.nvim_buf_get_name(bufnr),
      'localhost:4200',
      '--action', 'queries',
      '--re-name', '^' .. string.sub(name, 2, #name - 1) .. '$'
    }
    close_term()
    launch_term(cmd)
  else
    vim.notify('No query found near cursor with `name` property')
  end
end


function M.cr8_run_file()
  local cmd = {
    'cr8',
    'run-spec',
    api.nvim_buf_get_name(0),
    'localhost:4200',
  }
  close_term()
  launch_term(cmd)
end


function M.sendLine(line)
  if not jobid then
    return
  end
  vim.fn.chansend(jobid, line .. '\n')
end

function M.sendSelection()
  if not jobid then
    return
  end
  local start_row, start_col = unpack(api.nvim_buf_get_mark(0, '<'))
  local end_row, end_col = unpack(api.nvim_buf_get_mark(0, '>'))
  local mode = vim.fn.visualmode()
  local offset
  if mode == '' then -- in block mode all following lines are indented
    offset = start_col
  elseif mode == 'V' then
    end_row = end_row + 1
    offset = 0
  else
    offset = 0
  end
  local lines = api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  for idx, line in pairs(lines) do
    local l
    if idx == 1 and idx == #lines then
      l = line:sub(start_col + 1, end_col + 1)
    elseif idx == 1 then
      l = line:sub(start_col + 1)
    elseif idx == #lines then
      l = line:sub(offset + 1, end_col > #line and #line or end_col + 1)
    elseif offset > 0 then
      l = line:sub(offset + 1)
    else
      l = line
    end
    vim.fn.chansend(jobid, l .. '\n')
  end
end


return M
