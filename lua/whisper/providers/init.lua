local config = require("whisper.config")

local M = {}

local loaded = {}

local function get(name)
  if not loaded[name] then
    loaded[name] = require("whisper.providers." .. name)
  end
  return loaded[name]
end

function M.complete(route, prompt, opts, callback)
  if not config.current.routes then
    return callback(nil, "whisper not initialized — call require('whisper').setup() first")
  end
  local provider_name = config.current.routes[route]
  if not provider_name then
    return callback(nil, "no provider configured for route: " .. route)
  end

  local cfg = config.current.providers[provider_name]
  if (provider_name == "anthropic" or provider_name == "vertex") and not opts.model then
    opts.model = (route == "expand" or route == "ask") and cfg.model_expand or cfg.model_whisper
  end

  get(provider_name).complete(prompt, opts, callback)
end

return M
