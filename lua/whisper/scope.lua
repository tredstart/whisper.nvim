local M = {}

local block_types = {
  function_declaration = true, function_definition = true, function_item = true,
  method_declaration = true, method_definition = true,
  ["function"] = true, arrow_function = true, lambda = true,
  if_statement = true, for_statement = true, while_statement = true,
  class_declaration = true, class_definition = true,
  impl_item = true, struct_item = true,
}

local top_level_types = {
  function_declaration = true, function_definition = true, function_item = true,
  method_declaration = true, method_definition = true,
  ["function"] = true, arrow_function = true,
  class_declaration = true, class_definition = true,
  impl_item = true,
}

local function lines_from_range(bufnr, start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  return {
    lines = lines,
    text = table.concat(lines, "\n"),
    start_row = start_row,
    end_row = end_row,
  }
end

local function fallback_block(bufnr, row)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local s = math.max(0, row - 5)
  local e = math.min(total - 1, row + 5)
  local b = lines_from_range(bufnr, s, e)
  b.node_type = "fallback"
  b.cursor_row = row
  b.cursor_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  return b
end

function M.get_block_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return fallback_block(bufnr, row) end

  local tree = parser:parse()[1]
  if not tree then return fallback_block(bufnr, row) end

  local node = tree:root():named_descendant_for_range(row, 0, row, 0)
  while node do
    if block_types[node:type()] then
      local s, _, e, _ = node:range()
      if s == row then
        local b = lines_from_range(bufnr, s, e)
        b.node_type = node:type()
        return b
      end
    end
    node = node:parent()
  end

  return fallback_block(bufnr, row)
end

function M.get_enclosing_block(bufnr, row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return nil end

  local tree = parser:parse()[1]
  if not tree then return nil end

  local node = tree:root():named_descendant_for_range(row, 0, row, 0)
  while node do
    if block_types[node:type()] then
      local s, _, e, _ = node:range()
      local b = lines_from_range(bufnr, s, e)
      b.node_type = node:type()
      return b
    end
    node = node:parent()
  end
  return nil
end

function M.get_all_blocks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return {} end

  local tree = parser:parse()[1]
  if not tree then return {} end

  local blocks = {}
  local function walk(node)
    if block_types[node:type()] then
      local s, _, e, _ = node:range()
      local b = lines_from_range(bufnr, s, e)
      b.node_type = node:type()
      table.insert(blocks, b)
      return
    end
    for child in node:iter_children() do
      walk(child)
    end
  end
  walk(tree:root())
  return blocks
end

function M.get_block_after(row)
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return nil end

  local tree = parser:parse()[1]
  if not tree then return nil end

  local best = nil
  local function walk(node)
    if block_types[node:type()] then
      local s, _, e, _ = node:range()
      if s > row and s <= row + 2 and (not best or s < best.start_row) then
        best = lines_from_range(bufnr, s, e)
        best.node_type = node:type()
      end
    end
    for child in node:iter_children() do
      walk(child)
    end
  end
  walk(tree:root())
  return best
end

function M.get_comment_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok and parser then
    local tree = parser:parse()[1]
    if tree then
      local node = tree:root():named_descendant_for_range(row, 0, row, 0)
      while node do
        if node:type():match("comment") then
          local s, _, e, _ = node:range()
          local lines = vim.api.nvim_buf_get_lines(bufnr, s, e + 1, false)
          return { text = table.concat(lines, "\n"), row = s, end_row = e }
        end
        node = node:parent()
      end
    end
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if line and line:match("^%s*[#/%-]") then
    return { text = line, row = row, end_row = row }
  end
  return nil
end

return M
