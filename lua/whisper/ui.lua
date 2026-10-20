local config = require("whisper.config")

local M = {}

local ns = vim.api.nvim_create_namespace("whisper")

local function wrap_text(text, prefix, width)
  local max = width - #prefix - 2
  if max < 20 then max = 20 end

  local lines = {}
  for segment in text:gmatch("([^\n]*)") do
    if #segment == 0 then
      table.insert(lines, "")
    else
      while #segment > max do
        local cut = max
        local space = segment:sub(1, max):match(".*()%s")
        if space and space > max * 0.4 then cut = space end
        table.insert(lines, segment:sub(1, cut))
        segment = segment:sub(cut + 1):match("^%s*(.*)$")
      end
      if #segment > 0 then
        table.insert(lines, segment)
      end
    end
  end
  return lines
end

local function get_text_area_width()
  local win = vim.api.nvim_get_current_win()
  local info = vim.fn.getwininfo(win)[1]
  local w = info.width - info.textoff
  return math.min(w, 100)
end

local function make_virt_lines(text, prefix, hl)
  local wrapped = wrap_text(text, prefix, get_text_area_width())
  local virt = {}
  for _, line in ipairs(wrapped) do
    table.insert(virt, { { prefix .. line, hl } })
  end
  return virt
end

function M.show_whisper(bufnr, row, text)
  if not text or text == "" then return end
  local cfg = config.current.display
  M.clear_line(bufnr, row)
  if text:lower():match("^%s*ok%s*$") then
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      virt_text = { { " ✓", "DiagnosticOk" } },
      virt_text_pos = "eol",
    })
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_lines = make_virt_lines(text, cfg.prefix, cfg.whisper_hl),
    virt_lines_above = false,
  })
end

function M.show_answer(bufnr, row, text)
  if not text or text == "" then return end
  local cfg = config.current.display
  M.clear_line(bufnr, row)
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_lines = make_virt_lines(text, cfg.prefix, cfg.answer_hl),
    virt_lines_above = false,
  })
end

function M.clear_line(bufnr, row)
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, 0 }, { row, -1 }, {})
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark[1])
  end
end

function M.clear_buf(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local active_spinners = {}

function M.show_spinner(bufnr, row)
  M.clear_line(bufnr, row)
  local frame = 1
  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_text = { { " " .. spinner_frames[frame] .. " thinking...", "DiagnosticInfo" } },
    virt_text_pos = "eol",
  })
  local key = bufnr .. ":" .. row
  local timer = assert(vim.uv.new_timer())
  active_spinners[key] = { timer = timer, mark_id = mark_id, bufnr = bufnr, row = row }
  timer:start(100, 100, vim.schedule_wrap(function()
    local s = active_spinners[key]
    if not s then return end
    frame = (frame % #spinner_frames) + 1
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
      id = s.mark_id,
      virt_text = { { " " .. spinner_frames[frame] .. " thinking...", "DiagnosticInfo" } },
      virt_text_pos = "eol",
    })
  end))
end

function M.hide_spinner(bufnr, row)
  local key = bufnr .. ":" .. row
  local s = active_spinners[key]
  if s then
    s.timer:stop()
    s.timer:close()
    pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, s.mark_id)
    active_spinners[key] = nil
  end
end

local active_proposal = nil

function M.propose_diff(bufnr, start_row, end_row, new_text, on_decide)
  if active_proposal then
    M.dismiss_proposal()
  end

  local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_lines = vim.split(new_text, "\n")

  local modified = {}
  for i = 1, start_row do
    table.insert(modified, original_lines[i])
  end
  for _, line in ipairs(new_lines) do
    table.insert(modified, line)
  end
  for i = end_row + 1, #original_lines do
    table.insert(modified, original_lines[i])
  end

  local orig_win = vim.api.nvim_get_current_win()
  vim.cmd("diffthis")

  vim.cmd("vsplit")
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, scratch)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, modified)
  vim.bo[scratch].filetype = vim.bo[bufnr].filetype
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.api.nvim_buf_set_name(scratch, "[whisper proposal]")
  vim.cmd("diffthis")

  vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })

  local scratch_win = vim.api.nvim_get_current_win()

  local function cleanup()
    pcall(vim.cmd, "diffoff!")
    vim.api.nvim_set_current_win(orig_win)
    pcall(vim.cmd, "diffoff!")
    pcall(vim.api.nvim_win_close, scratch_win, true)
    pcall(vim.keymap.del, "n", "<leader>wy", { buffer = bufnr })
    pcall(vim.keymap.del, "n", "<leader>wn", { buffer = bufnr })
    pcall(vim.keymap.del, "n", "<leader>wy", { buffer = scratch })
    pcall(vim.keymap.del, "n", "<leader>wn", { buffer = scratch })
    active_proposal = nil
  end

  local function bind(buf)
    vim.keymap.set("n", "<leader>wy", function()
      cleanup()
      on_decide(true)
    end, { buffer = buf, nowait = true })

    vim.keymap.set("n", "<leader>wn", function()
      cleanup()
      on_decide(false)
    end, { buffer = buf, nowait = true })
  end

  bind(bufnr)
  bind(scratch)

  active_proposal = { cleanup = cleanup }
end

function M.dismiss_proposal()
  if active_proposal then
    active_proposal.cleanup()
  end
end

function M.namespace()
  return ns
end

return M
