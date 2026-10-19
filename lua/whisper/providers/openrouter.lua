local http = require("whisper.util.http")
local config = require("whisper.config")

local M = {}

function M.complete(prompt, opts, callback)
  local cfg = config.current.providers.openrouter
  local api_key = vim.env.OPENROUTER_API_KEY
  if not api_key then
    return callback(nil, "OPENROUTER_API_KEY not set")
  end

  local messages = {}
  if opts.system then
    table.insert(messages, { role = "system", content = opts.system })
  end
  table.insert(messages, { role = "user", content = prompt })

  http.post("https://openrouter.ai/api/v1/chat/completions", {
    ["Authorization"] = "Bearer " .. api_key,
  }, {
    model = opts.model or cfg.model,
    max_tokens = opts.max_tokens or 256,
    messages = messages,
  }, function(data, err)
    if err then return callback(nil, err) end
    if data.choices and data.choices[1] then
      callback(data.choices[1].message.content, nil)
    else
      callback(nil, "unexpected response: " .. vim.json.encode(data))
    end
  end)
end

return M
