local M = {}

M.entries = {}

local cache_dir = vim.fn.stdpath("cache")
local log_path = cache_dir .. "/whisper.log"
vim.fn.mkdir(cache_dir, "p")

local function write_file(msg)
  local f = io.open(log_path, "a")
  if f then
    f:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), msg))
    f:close()
  end
end

function M.info(msg)
  table.insert(M.entries, { level = "INFO", msg = msg, time = os.time() })
  write_file("INFO: " .. msg)
end

function M.warn(msg)
  table.insert(M.entries, { level = "WARN", msg = msg, time = os.time() })
  write_file("WARN: " .. msg)
  vim.notify("whisper: " .. msg, vim.log.levels.WARN)
end

function M.err(msg)
  table.insert(M.entries, { level = "ERROR", msg = msg, time = os.time() })
  write_file("ERROR: " .. msg)
  vim.notify("whisper: " .. msg, vim.log.levels.ERROR)
end

function M.dump()
  for _, e in ipairs(M.entries) do
    print(string.format("[%s] %s: %s", os.date("%H:%M:%S", e.time), e.level, e.msg))
  end
  if #M.entries == 0 then
    print("whisper: no log entries")
  end
  print("log file: " .. log_path)
end

function M.path()
  return log_path
end

return M
