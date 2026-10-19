local M = {}

M.defaults = {
  mode = "cloud",

  providers = {
    ollama = {
      endpoint = "http://localhost:11434",
      model = "qwen2.5-coder:1.5b",
    },
    anthropic = {
      model_whisper = "claude-haiku-5-5",
      model_expand = "claude-sonnet-5-5",
    },
    openrouter = {
      model = "auto",
    },
    claude = {
      bin = "claude",
      model = nil,
    },
    vertex = {
      project_id = vim.env.ANTHROPIC_VERTEX_PROJECT_ID or "",
      region = vim.env.CLOUD_ML_REGION or "global",
      model_whisper = "claude-haiku-5-5",
      model_expand = "claude-sonnet-5-5",
    },
  },

  routes = nil,

  keymaps = {
    whisper_cursor = "<leader>wc",
    whisper_block = "<leader>wb",
    whisper_file = "<leader>wf",
    expand = "<leader>we",
    ask = "<leader>wa",
  },

  display = {
    whisper_hl = "Comment",
    answer_hl = "Comment",
    clear_on_insert = true,
    prefix = "~ ",
  },

  cache = {
    enabled = true,
    on_save = true,
  },
}

M.current = {}

local mode_routes = {
  ["local"] = { whisper = "ollama", expand = "ollama", ask = "ollama" },
  hybrid = { whisper = "ollama", expand = "anthropic", ask = "anthropic" },
  cloud = { whisper = "anthropic", expand = "anthropic", ask = "anthropic" },
  vertex = { whisper = "vertex", expand = "vertex", ask = "vertex" },
  vertex_hybrid = { whisper = "ollama", expand = "vertex", ask = "vertex" },
  claude = { whisper = "claude", expand = "claude", ask = "claude" },
  claude_hybrid = { whisper = "ollama", expand = "claude", ask = "claude" },
}

function M.setup(opts)
  M.current = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  if not M.current.routes then
    M.current.routes = mode_routes[M.current.mode] or mode_routes.cloud
  end
end

return M
