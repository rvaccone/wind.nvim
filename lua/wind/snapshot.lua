local api = vim.api
local fn = vim.fn

local M = {}

---@class WindSnapshotLeaf
---@field path string
---@field view table
---@field width number Fraction of the screen
---@field height number Fraction of the screen
---@field focused? boolean

---@alias WindSnapshotNode
---| { [1]: "leaf", [2]: WindSnapshotLeaf }
---| { [1]: "row"|"col", [2]: WindSnapshotNode[] }

--- Capture the current layout as a content-only tree. Excluded windows are
--- pruned; single-child containers collapse. Sizes are fractions of the
--- screen so restores survive resizes and absent side windows.
---@return WindSnapshotNode|nil
function M.capture()
	local engine = require("wind.engine")
	local columns, lines = vim.o.columns, vim.o.lines
	local current = api.nvim_get_current_win()

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
					focused = win == current or nil,
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

--- Structure and content only — views, sizes, and focus change constantly
--- and must not count as drift.
---@param node WindSnapshotNode|nil
---@return table|nil
function M.normalize(node)
	if not node then
		return nil
	end
	if node[1] == "leaf" then
		return { "leaf", node[2].path }
	end
	local children = {}
	for i, child in ipairs(node[2]) do
		children[i] = M.normalize(child)
	end
	return { node[1], children }
end

---@param win integer
---@param leaf WindSnapshotLeaf
local function set_leaf(win, leaf)
	local buf
	if leaf.path == "" then
		buf = api.nvim_create_buf(true, false)
	else
		-- bufadd + set_buf never abandons a modified buffer the way :edit
		-- can under 'nohidden', so a restore cannot fail halfway through.
		buf = fn.bufadd(leaf.path)
		pcall(fn.bufload, buf)
		vim.bo[buf].buflisted = true
	end
	api.nvim_win_set_buf(win, buf)
	if leaf.path ~= "" and vim.bo[buf].filetype == "" then
		api.nvim_win_call(win, function()
			vim.cmd("silent! filetype detect")
		end)
	end
end

---@param node WindSnapshotNode
---@param win integer
---@param leaves { win: integer, leaf: WindSnapshotLeaf }[]
local function build(node, win, leaves)
	if node[1] == "leaf" then
		set_leaf(win, node[2])
		leaves[#leaves + 1] = { win = win, leaf = node[2] }
		return
	end

	-- winlayout() children are in screen order, so building rightbelow
	-- reproduces the geometry regardless of flow or split options.
	local orientation = node[1] == "row" and "vsplit" or "split"
	local windows = { win }
	for _ = 2, #node[2] do
		api.nvim_set_current_win(windows[#windows])
		vim.cmd("rightbelow " .. orientation)
		windows[#windows + 1] = api.nvim_get_current_win()
	end
	for i, child in ipairs(node[2]) do
		build(child, windows[i], leaves)
	end
end

--- Rebuild a captured layout in the current tabpage. Content windows are
--- replaced; excluded windows are untouched. Buffers are never written,
--- closed, or edited.
---@param tree WindSnapshotNode|nil
---@return boolean restored
function M.restore(tree)
	if not tree then
		return false
	end

	local engine = require("wind.engine")
	local content = engine.list()

	local keep = api.nvim_get_current_win()
	if not engine.is_content(keep) then
		keep = content[1]
	end
	if not keep then
		vim.cmd("rightbelow vsplit")
		keep = api.nvim_get_current_win()
	end
	for _, win in ipairs(content) do
		if win ~= keep then
			pcall(api.nvim_win_close, win, true)
		end
	end

	local leaves = {}
	build(tree, keep, leaves)

	local columns, lines = vim.o.columns, vim.o.lines
	for _, item in ipairs(leaves) do
		if api.nvim_win_is_valid(item.win) then
			pcall(api.nvim_win_set_width, item.win, math.floor(item.leaf.width * columns + 0.5))
			pcall(api.nvim_win_set_height, item.win, math.floor(item.leaf.height * lines + 0.5))
		end
	end

	local focus = leaves[1] and leaves[1].win
	for _, item in ipairs(leaves) do
		if api.nvim_win_is_valid(item.win) then
			api.nvim_win_call(item.win, function()
				pcall(fn.winrestview, item.leaf.view)
			end)
			if item.leaf.focused then
				focus = item.win
			end
		end
	end
	if focus and api.nvim_win_is_valid(focus) then
		api.nvim_set_current_win(focus)
	end

	return true
end

return M
