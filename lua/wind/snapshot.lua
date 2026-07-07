local api = vim.api
local fn = vim.fn

local M = {}

---@alias WindSnapshotNode
---| { [1]: "leaf", [2]: { path: string, view: table, width: number, height: number } }
---| { [1]: "row"|"col", [2]: WindSnapshotNode[] }

--- Capture the current layout as a content-only tree. Excluded windows are
--- pruned; single-child containers collapse. Sizes are fractions of the
--- screen so restores survive resizes and absent side windows.
---@return WindSnapshotNode|nil
function M.capture()
	local engine = require("wind.engine")
	local columns, lines = vim.o.columns, vim.o.lines

	local function walk(node)
		if node[1] == "leaf" then
			local win = node[2]
			if not engine.is_content(win) then
				return nil
			end
			return {
				"leaf",
				{
					path = api.nvim_buf_get_name(api.nvim_win_get_buf(win)),
					view = api.nvim_win_call(win, fn.winsaveview),
					width = api.nvim_win_get_width(win) / columns,
					height = api.nvim_win_get_height(win) / lines,
				},
			}
		end

		local children = {}
		for _, child in ipairs(node[2]) do
			local kept = walk(child)
			if kept then
				children[#children + 1] = kept
			end
		end

		if #children == 0 then
			return nil
		end
		if #children == 1 then
			return children[1]
		end
		return { node[1], children }
	end

	return walk(fn.winlayout())
end

return M
