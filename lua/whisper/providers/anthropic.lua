local http = require("whisper.util.http")
local config = require("whisper.config")

local M = {}

function M.complete(prompt, opts, callback)
  local cfg = config.current.providers.anthropic
  local api_key = vim.env.ANTHROPIC_API_KEY
  if not api_key then
    return callback(nil, "ANTHROPIC_API_KEY not set")
  end

  local model = opts.model or cfg.model_whisper
  local body = {
    model = model,
    max_tokens = opts.max_tokens or 256,
    messages = { { role = "user", content = prompt } },
  }
  if opts.system then
    body.system = opts.system
  end

  http.post("https://api.anthropic.com/v1/messages", {
    ["x-api-key"] = api_key,
    ["anthropic-version"] = "2023-06-01",
  }, body, function(data, err)
    if err then return callback(nil, err) end
    if data.content and data.content[1] then
      callback(data.content[1].text, nil)
    else
      callback(nil, "unexpected response: " .. vim.json.encode(data))
    end
  end)
end

return M
