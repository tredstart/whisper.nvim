local M = {}

function M.post(url, headers, body, callback)
  local json_body = vim.json.encode(body)
  local args = { "curl", "-s", "-X", "POST", url, "-H", "Content-Type: application/json" }
  for k, v in pairs(headers or {}) do
    table.insert(args, "-H")
    table.insert(args, k .. ": " .. v)
  end
  table.insert(args, "-d")
  table.insert(args, json_body)

  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "curl failed: " .. (result.stderr or "unknown error"))
        return
      end
      local ok, decoded = pcall(vim.json.decode, result.stdout)
      if not ok then
        local preview = result.stdout:sub(1, 200)
        callback(nil, "json parse error: " .. preview)
        return
      end
      callback(decoded, nil)
    end)
  end)
end

return M
