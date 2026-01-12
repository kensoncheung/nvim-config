local ok1, _ = pcall(require, "lspconfig")
if not ok1 then return end

local ok2, mason = pcall(require, "mason")
if not ok2 then return end

local ok3, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not ok3 then return end

local ok4, null_ls = pcall(require, "null-ls")
if not ok4 then return end

local ok5, masonlsp = pcall(require, "mason-lspconfig")
if not ok5 then return end

-- Setup Mason (Installer)
mason.setup()
masonlsp.setup {
  ensure_installed = { "eslint", "bashls", "pyright", "ruff" },
}

-- =============================================================================
--  LSP CONFIGURATION (Neovim 0.11+)
-- =============================================================================

-- 1. Capabilities (Required for nvim-cmp autocompletion)
local capabilities = cmp_nvim_lsp.default_capabilities()

-- 2. Global Keymaps (Modern replacement for 'on_attach')
-- This runs automatically whenever ANY LSP attaches to a buffer
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    local map = vim.keymap.set

    -- Your custom keymaps
    map("n", "<c-h>", vim.diagnostic.goto_prev, opts)
    map("n", "<c-l>", vim.diagnostic.goto_next, opts)
    map("n", "<c-m-]>", vim.lsp.buf.hover, opts)
    map("n", "<c-]>", vim.lsp.buf.definition, opts)
    map("n", "<leader>rn", vim.lsp.buf.rename, opts)
  end,
})

-- 3. Configure & Enable Standard Servers
-- We loop through servers that just need default config + capabilities
local servers = { "eslint", "bashls", "pyright" }

for _, server in ipairs(servers) do
  vim.lsp.config(server, {
    capabilities = capabilities,
  })
  vim.lsp.enable(server)
end

-- 4. Configure & Enable Ruff (Custom Logic)
vim.lsp.config("ruff", {
  capabilities = capabilities,
  on_attach = function(client, bufnr)
    -- Disable formatting for Ruff if you want to use something else,
    -- or keep your specific logic here.
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
    end
  end,
})
vim.lsp.enable("ruff")


-- =============================================================================
--  DIAGNOSTICS & UI
-- =============================================================================

local signs = {
  { name = "DiagnosticSignError", text = "" },
  { name = "DiagnosticSignWarn", text = "" },
  { name = "DiagnosticSignHint", text = "" },
  { name = "DiagnosticSignInfo", text = "" },
}

for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

-- Toggle LSP Functions
local lsp_is_on = true

_G.turn_off_lsp = function()
  lsp_is_on = false
  vim.diagnostic.config {
    virtual_text = false,
    signs = false,
    underline = false,
  }
end

_G.turn_on_lsp = function()
  lsp_is_on = true
  vim.diagnostic.config({
    virtual_text = {
      source = "always",
      prefix = '▎',
    },
    signs = {
      active = signs,
    },
    underline = true,
  })
end

_G.toggle_lsp = function()
  if lsp_is_on == true then
    _G.turn_off_lsp()
  else
    _G.turn_on_lsp()
  end
end

_G.turn_on_lsp()

-- UI Borders
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})


-- =============================================================================
--  NULL-LS & FLUTTER
-- =============================================================================

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics

null_ls.setup {
  debug = false,
  sources = {
    formatting.prettier.with { extra_args = { } },
    -- formatting.black.with { extra_args = { "--fast" } },
    -- formatting.yapf,
    formatting.stylua,
    -- diagnostics.flake8,
  },
}

-- =============================================================================
--  HIGHLIGHT ON YANK (Copy)
-- =============================================================================
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({
      higroup = "IncSearch", -- The color group (IncSearch is usually yellow/orange)
      timeout = 200,         -- How long the flash lasts (in milliseconds)
    })
  end,
})

require("flutter-tools").setup{} -- use defaults
