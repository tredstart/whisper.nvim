local config = require("whisper.config")
local log = require("whisper.log")

local M = {}

function M.complete(prompt, opts, callback)
  local cfg = config.current.providers.claude or {}
  local bin = cfg.bin or "claude"
  local args = { bin, "-p", "--allowedTools", "" }

  if cfg.model then
    table.insert(args, "--model")
    table.insert(args, cfg.model)
  end

  log.info("claude: spawning, prompt_len=" .. #prompt)
  log.info("claude: cmd=" .. table.concat(args, " "))

  vim.system(args, { text = true, stdin = prompt }, function(result)
    vim.schedule(function()
      log.info("claude: exit_code=" .. result.code
        .. " stdout_len=" .. #(result.stdout or "")
        .. " stderr_len=" .. #(result.stderr or ""))
      if result.code ~= 0 then
        log.err("claude: stderr=" .. (result.stderr or ""):sub(1, 300))
        callback(nil, "claude cli failed (exit " .. result.code .. "): " .. (result.stderr or ""):sub(1, 100))
        return
      end
      if result.stdout == "" then
        log.warn("claude: empty stdout")
        callback(nil, "claude returned empty response")
        return
      end
      log.info("claude: raw_response=" .. result.stdout:sub(1, 200))
      callback(vim.trim(result.stdout), nil)
    end)
  end)
end

return M
