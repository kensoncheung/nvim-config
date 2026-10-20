-- 兼容 shim
--
-- nvim-treesitter 已由 master 切換到 main 分支，main 移除了 lua/nvim-treesitter/ts_utils.lua。
-- 但各專案的 ~/.devbase/project.vim.lua（含 erp，共 11 個 repo，皆為 git tracked）仍使用
-- `require("nvim-treesitter.ts_utils")` 的 get_node_at_cursor / get_node_text。
--
-- 這個 shim 放在使用者設定（~/.config/nvim/lua，runtimepath 最前）以 Neovim 核心 API 補回，
-- 因此無需修改任何專案檔案。
local M = {}

--- 取得游標所在的最小 named node。
--- 舊版 ts_utils 預設會考慮 injected 語言，這裡維持相同行為（ignore_injections 預設 false）。
---@param winnr integer? 視窗編號（預設 0 = 當前視窗）
---@param ignore_injections boolean? 是否忽略注入語言
---@return TSNode?
function M.get_node_at_cursor(winnr, ignore_injections)
  winnr = winnr or 0
  if not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local buf = vim.api.nvim_win_get_buf(winnr)
  local pos = vim.api.nvim_win_get_cursor(winnr)
  local row, col = pos[1] - 1, pos[2]

  local ok, node = pcall(function()
    -- 互動時 highlighter 通常已解析可見範圍；這裡補保險，避免剛開檔時取不到節點。
    local parser = vim.treesitter.get_parser(buf)
    if parser then
      parser:parse { row, row + 1 }
    end

    return vim.treesitter.get_node {
      bufnr = buf,
      pos = { row, col },
      ignore_injections = ignore_injections and true or false,
    }
  end)

  if not ok then
    return nil
  end

  return node
end

--- 取得 node（或 range）對應的文字。
---@param node TSNode|table
---@param bufnr integer? 緩衝區編號（預設 0 = 當前緩衝區）
---@param opts table?
---@return string[]
function M.get_node_text(node, bufnr, opts)
  return vim.treesitter.get_node_text(node, bufnr or 0, opts)
end

return M
