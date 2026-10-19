local http = require("whisper.util.http")
local config = require("whisper.config")

local M = {}

function M.complete(prompt, opts, callback)
  local cfg = config.current.providers.ollama
  http.post(cfg.endpoint .. "/api/generate", {}, {
    model = opts.model or cfg.model,
    prompt = prompt,
    stream = false,
  }, function(data, err)
    if err then return callback(nil, err) end
    callback(data.response, nil)
  end)
end

return M
