local M = {}

local function number_lines(code, start_line)
  local numbered = {}
  local n = start_line or 1
  for line in (code .. "\n"):gmatch("(.-)\n") do
    table.insert(numbered, string.format("%d: %s", n, line))
    n = n + 1
  end
  return table.concat(numbered, "\n")
end

function M.whisper_line(code, filetype, cursor_line)
  return string.format(
    "You are reviewing %s code. Give ONE observation about this specific line:"
      .. " a real bug, missed edge case, or concrete improvement."
      .. " One sentence, under 30 words. No code snippets."
      .. " Be accurate — do not claim something is missing if it is present."
      .. ' If nothing is wrong, respond with just "ok".\n\nLine: %s\n\nContext:\n%s',
    filetype,
    cursor_line,
    code
  )
end

function M.whisper_block(code, filetype, start_line)
  return string.format(
    "You are reviewing %s code. Give ONE observation: a real bug, missed edge case,"
      .. " or concrete improvement. Be accurate."
      .. '\nRespond EXACTLY as: LINE_NUMBER: observation (under 30 words)'
      .. '\nIf nothing is wrong, respond with just "ok".\n\n%s',
    filetype,
    number_lines(code, start_line)
  )
end

function M.expand(code, whisper_text, filetype)
  return string.format(
    'Observation: "%s"\n\nCode:\n```\n%s\n```\n\n'
      .. "Apply the observation. Output ONLY the replacement code between <code> and </code> tags."
      .. " No markdown, no explanation, no commentary."
      .. " If the code should be deleted entirely, output <code></code> with nothing between.",
    whisper_text,
    code
  )
end

function M.ask(comment_text, surrounding_code, filetype)
  return string.format(
    "Answer this comment about the code. Two sentences max.\n\nComment: %s\n\n%s",
    comment_text,
    surrounding_code
  )
end

function M.parse_line_response(response)
  local line_num, message = response:match("^(%d+):%s*(.+)$")
  if line_num and message then
    return tonumber(line_num) - 1, message
  end
  return nil, response
end

return M
