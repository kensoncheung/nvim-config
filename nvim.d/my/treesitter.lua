-- nvim-treesitter 已切換到 main 分支（完整重寫）。
-- main 不再提供 nvim-treesitter.configs / highlight / indent / playground 等模組，
-- 高亮與縮排改由 Neovim 核心 API 驅動（參見 :h nvim-treesitter）。
local status_ok, ts = pcall(require, "nvim-treesitter")
if not status_ok then
  return
end

ts.setup {}

-- 取代舊版 `ensure_installed = "all"`：只補裝缺少的 parser
-- （`install "all"` 會嘗試編譯全部 ~300 個 parser，且需要 `tree-sitter` CLI）
local ensure = {
  "lua", "luadoc", "vim", "vimdoc", "query", "bash", "python", "javascript", "typescript",
  "tsx", "json", "yaml", "toml", "markdown", "markdown_inline", "html", "css", "go", "rust",
  "c", "cpp", "diff", "gitcommit", "gitignore", "dockerfile", "regex", "comment",
}
local missing = {}
for _, lang in ipairs(ensure) do
  if not vim.treesitter.language.add(lang, { error = false }) then
    table.insert(missing, lang)
  end
end
if #missing > 0 then
  ts.install(missing)
end

-- 取代舊版 `highlight = { enable = true }` 與 `indent = { enable = true, disable = { "javascript" } }`
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local buf = args.buf
    local ft = vim.bo[buf].filetype
    local lang = vim.treesitter.language.get_lang(ft)

    if not lang or not vim.treesitter.language.add(lang) then
      return
    end

    vim.treesitter.start(buf, lang)

    if ft ~= "javascript" then
      vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- 舊版內建的 context_commentstring 模組已移除，改用獨立外掛
-- （JoosepAlviste/nvim-ts-context-commentstring）
vim.g.skip_ts_context_commentstring_module = true
pcall(function()
  require("ts_context_commentstring").setup {}
end)
