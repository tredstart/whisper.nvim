if vim.g.loaded_whisper then return end
vim.g.loaded_whisper = true

vim.api.nvim_create_user_command("WhisperCursor", function()
  require("whisper").whisper_cursor()
end, {})

vim.api.nvim_create_user_command("WhisperFile", function()
  require("whisper").whisper_file()
end, {})

vim.api.nvim_create_user_command("WhisperBlock", function()
  require("whisper").whisper_block()
end, {})

vim.api.nvim_create_user_command("WhisperExpand", function()
  require("whisper").expand()
end, {})

vim.api.nvim_create_user_command("WhisperAsk", function()
  require("whisper").ask()
end, {})

vim.api.nvim_create_user_command("WhisperLog", function()
  require("whisper.log").dump()
end, {})

vim.api.nvim_create_user_command("WhisperLogFile", function()
  vim.cmd.edit(require("whisper.log").path())
end, {})
