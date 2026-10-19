local http = require("whisper.util.http")
local config = require("whisper.config")

local M = {}

local function get_access_token(callback)
  vim.system({ "gcloud", "auth", "print-access-token" }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "gcloud auth failed: " .. (result.stderr or ""))
        return
      end
      callback(vim.trim(result.stdout), nil)
    end)
  end)
end

function M.complete(prompt, opts, callback)
  local cfg = config.current.providers.vertex

  get_access_token(function(token, err)
    if err then return callback(nil, err) end

    local model = opts.model or cfg.model_whisper
    local region = cfg.region or "global"
    local url = string.format(
      "https://%s-aiplatform.googleapis.com/v1/projects/%s/locations/%s/publishers/anthropic/models/%s:rawPredict",
      region,
      cfg.project_id,
      region,
      model
    )

    local body = {
      anthropic_version = "vertex-2023-10-16",
      max_tokens = opts.max_tokens or 256,
      messages = { { role = "user", content = prompt } },
    }
    if opts.system then
      body.system = opts.system
    end

    http.post(url, {
      ["Authorization"] = "Bearer " .. token,
    }, body, function(data, post_err)
      if post_err then return callback(nil, post_err) end
      if data.content and data.content[1] then
        callback(data.content[1].text, nil)
      else
        callback(nil, "unexpected response: " .. vim.json.encode(data))
      end
    end)
  end)
end

return M
