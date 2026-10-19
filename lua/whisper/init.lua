local config = require("whisper.config")
local cache = require("whisper.cache")
local scope = require("whisper.scope")
local ui = require("whisper.ui")
local prompt = require("whisper.prompt")
local provider = require("whisper.providers")
local log = require("whisper.log")

local M = {}

local whispers = {}

local function upsert_whisper(entry)
  for i, w in ipairs(whispers) do
    if w.bufnr == entry.bufnr and w.start_row == entry.start_row and w.end_row == entry.end_row then
      whispers[i] = entry
      return
    end
  end
  table.insert(whispers, entry)
end

local function shift_whispers(bufnr, after_row, delta)
  for _, w in ipairs(whispers) do
    if w.bufnr == bufnr and w.start_row > after_row then
      w.start_row = w.start_row + delta
      w.end_row = w.end_row + delta
    end
  end
end

function M.setup(opts)
  config.setup(opts)
  log.info("setup complete, mode=" .. config.current.mode)
  log.info("routes: whisper=" .. config.current.routes.whisper
    .. " expand=" .. config.current.routes.expand
    .. " ask=" .. config.current.routes.ask)

  local km = config.current.keymaps
  vim.keymap.set("n", km.whisper_cursor, M.whisper_cursor, { desc = "Whisper: line" })
  vim.keymap.set("n", km.whisper_file, M.whisper_file, { desc = "Whisper: file" })
  vim.keymap.set("n", km.expand, M.expand, { desc = "Whisper: expand" })
  vim.keymap.set("n", km.ask, M.ask, { desc = "Whisper: ask" })

  if km.whisper_block then
    vim.keymap.set("n", km.whisper_block, M.whisper_block, { desc = "Whisper: block" })
  end

  if config.current.cache.on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = vim.api.nvim_create_augroup("whisper_on_save", { clear = true }),
      callback = function(ev)
        M.on_save(ev.buf)
      end,
    })
  end

  if config.current.display.clear_on_insert then
    vim.api.nvim_create_autocmd("InsertEnter", {
      group = vim.api.nvim_create_augroup("whisper_clear_insert", { clear = true }),
      callback = function(ev)
        ui.clear_buf(ev.buf)
      end,
    })
  end
end

function M.whisper_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local cursor_line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
  if not cursor_line or cursor_line:match("^%s*$") then
    log.warn("whisper_cursor: empty line")
    return
  end

  local block = scope.get_block_at_cursor()
  local context = block and block.text or cursor_line
  local ft = vim.bo[bufnr].filetype

  log.info("whisper_cursor: row=" .. cursor_row .. " line=" .. cursor_line:sub(1, 60))
  ui.show_spinner(bufnr, cursor_row)

  local p = prompt.whisper_line(context, ft, cursor_line)
  log.info("whisper_cursor: prompt_len=" .. #p)

  provider.complete("whisper", p, {}, function(text, err)
    ui.hide_spinner(bufnr, cursor_row)
    if err then
      log.err("whisper_cursor: " .. err)
      return
    end
    log.info("whisper_cursor: response=" .. (text or "nil"):sub(1, 200))
    upsert_whisper({ bufnr = bufnr, start_row = cursor_row, end_row = cursor_row, hint = text })
    ui.show_whisper(bufnr, cursor_row, text)
  end)
end

function M.whisper_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local block = scope.get_block_at_cursor()
  if not block then
    log.warn("whisper_block: no block found")
    return
  end

  local ft = vim.bo[bufnr].filetype
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  log.info("whisper_block: type=" .. (block.node_type or "?")
    .. " rows=" .. block.start_row .. "-" .. block.end_row)

  ui.show_spinner(bufnr, cursor_row)

  local p = prompt.whisper_block(block.text, ft, block.start_row + 1)
  log.info("whisper_block: prompt_len=" .. #p)

  provider.complete("whisper", p, {}, function(text, err)
    ui.hide_spinner(bufnr, cursor_row)
    if err then
      log.err("whisper_block: " .. err)
      return
    end
    log.info("whisper_block: response=" .. (text or "nil"):sub(1, 200))
    upsert_whisper({ bufnr = bufnr, start_row = block.start_row, end_row = block.end_row, hint = text })
    local target_row, message = prompt.parse_line_response(text)
    if target_row then
      log.info("whisper_block: placing at row " .. target_row)
      ui.show_whisper(bufnr, target_row, message)
    else
      ui.show_whisper(bufnr, cursor_row, text)
    end
  end)
end

function M.whisper_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local blocks = scope.get_all_blocks(bufnr)
  local ft = vim.bo[bufnr].filetype
  log.info("whisper_file: found " .. #blocks .. " blocks, ft=" .. ft)
  whispers = {}

  for i, block in ipairs(blocks) do
    local b = block
    local idx = i
    log.info("whisper_file: block " .. idx .. " requesting (" .. b.start_row .. "-" .. b.end_row .. ")")
    ui.show_spinner(bufnr, b.start_row)

    local p = prompt.whisper_block(b.text, ft, b.start_row + 1)

    provider.complete("whisper", p, {}, function(text, err)
      ui.hide_spinner(bufnr, b.start_row)
      if err then
        log.err("whisper_file: block " .. idx .. " error: " .. err)
        return
      end
      log.info("whisper_file: block " .. idx .. " response=" .. (text or "nil"):sub(1, 100))
      upsert_whisper({ bufnr = bufnr, start_row = b.start_row, end_row = b.end_row, hint = text })
      local target_row, message = prompt.parse_line_response(text, b.start_row)
      if target_row then
        log.info("whisper_file: block " .. idx .. " placing at row " .. target_row)
        ui.show_whisper(bufnr, target_row, message)
      else
        ui.show_whisper(bufnr, b.start_row, text)
      end
    end)
  end
end

function M.expand()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local w = nil
  for _, entry in ipairs(whispers) do
    if entry.bufnr == bufnr and cursor_row >= entry.start_row and cursor_row <= entry.end_row then
      w = entry
      break
    end
  end
  if not w then
    log.warn("expand: no whisper at cursor — run wc, wb, or wf first")
    return
  end

  local start_row = w.start_row
  local end_row = w.end_row
  local enclosing = scope.get_enclosing_block(bufnr, start_row)
  if enclosing and (enclosing.start_row < start_row or enclosing.end_row > end_row) then
    start_row = enclosing.start_row
    end_row = enclosing.end_row
  end
  local code = table.concat(vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false), "\n")
  local hint = w.hint or "improve this code"
  local ft = vim.bo[bufnr].filetype

  log.info("expand: rows=" .. start_row .. "-" .. end_row .. " hint=" .. hint:sub(1, 80))

  ui.show_spinner(bufnr, start_row)

  local p = prompt.expand(code, hint, ft)
  log.info("expand: prompt_len=" .. #p)

  provider.complete("expand", p, { max_tokens = 1024 }, function(text, err)
    ui.hide_spinner(bufnr, start_row)
    if err then
      log.err("expand: " .. err)
      return
    end
    local extracted = text:match("<code>(.-)</code>")
    if extracted then
      text = extracted
    else
      text = text:gsub("^%s*```%w*%s*\n", ""):gsub("\n%s*```%s*$", "")
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local is_delete = text == ""
    local proposal = text
    log.info("expand: proposing " .. (is_delete and "deletion" or (#vim.split(text, "\n") .. " lines")))
    ui.propose_diff(bufnr, start_row, end_row, proposal, function(accepted)
      if accepted then
        log.info("expand: accepted, replacing rows " .. start_row .. "-" .. end_row)
        local lines = is_delete and {} or vim.split(text, "\n")
        local old_count = end_row - start_row + 1
        vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, lines)
        local delta = #lines - old_count
        if delta ~= 0 then
          shift_whispers(bufnr, end_row, delta)
        end
        for i = #whispers, 1, -1 do
          if whispers[i] == w then
            table.remove(whispers, i)
            break
          end
        end
      else
        log.info("expand: rejected")
      end
    end)
  end)
end

function M.ask()
  local bufnr = vim.api.nvim_get_current_buf()
  local comment = scope.get_comment_at_cursor()
  if not comment then
    log.warn("ask: no comment under cursor")
    return
  end

  local block = scope.get_block_after(comment.end_row) or scope.get_block_at_cursor()
  local surrounding = block and block.text or ""
  local ft = vim.bo[bufnr].filetype

  log.info("ask: comment=" .. comment.text:sub(1, 80)
    .. " block=" .. (block and (block.start_row .. "-" .. block.end_row) or "none"))
  ui.show_spinner(bufnr, comment.end_row)

  local p = prompt.ask(comment.text, surrounding, ft)

  provider.complete("ask", p, {}, function(text, err)
    ui.hide_spinner(bufnr, comment.end_row)
    if err then
      log.err("ask: " .. err)
      return
    end
    log.info("ask: response=" .. (text or "nil"):sub(1, 200))
    local s = comment.row
    local e = block and block.end_row or comment.end_row
    upsert_whisper({ bufnr = bufnr, start_row = s, end_row = e, hint = text })
    ui.show_answer(bufnr, comment.end_row, text)
  end)
end

function M.on_save(bufnr)
  if not config.current.cache.enabled then return end
  local blocks = scope.get_all_blocks(bufnr)
  local ft = vim.bo[bufnr].filetype
  local new_count = 0

  for _, block in ipairs(blocks) do
    local b = block
    if not cache.get(bufnr, b.text) then
      new_count = new_count + 1
      provider.complete("whisper", prompt.whisper_block(b.text, ft, b.start_row + 1), {}, function(text, err)
        if err then
          log.err("on_save: " .. err)
          return
        end
        log.info("on_save: cached block " .. b.start_row .. "-" .. b.end_row)
        cache.set(bufnr, b.text, text, b.start_row, b.end_row)
      end)
    end
  end
  if new_count > 0 then
    log.info("on_save: warming " .. new_count .. " new blocks out of " .. #blocks)
  end
end

return M
