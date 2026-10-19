local M = {}

local store = {}

local function hash(str)
  local h = 5381
  for i = 1, #str do
    h = ((h * 33) + str:byte(i)) % 2 ^ 32
  end
  return string.format("%x", h)
end

function M.hash(str)
  return hash(str)
end

function M.get(bufnr, block_text)
  local buf = store[bufnr]
  if not buf then return nil end
  return buf[hash(block_text)]
end

function M.set(bufnr, block_text, whisper_text, start_row, end_row)
  if not store[bufnr] then store[bufnr] = {} end
  store[bufnr][hash(block_text)] = {
    text = whisper_text,
    start_row = start_row,
    end_row = end_row,
  }
end

function M.clear(bufnr)
  if bufnr then
    store[bufnr] = nil
  else
    store = {}
  end
end

return M
