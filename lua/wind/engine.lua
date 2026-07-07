local api = vim.api
local fn = vim.fn

local config = require("wind.config")
local notify = require("wind.notify")

local M = {}

---@param win integer
---@return boolean
function M.is_content(win)
	if not api.nvim_win_is_valid(win) or api.nvim_win_get_config(win).relative ~= "" then
		return false
	end

	local excluded = config.get().windows.excluded
	local buf = api.nvim_win_get_buf(win)
	local filetype = vim.bo[buf].filetype

	if vim.tbl_contains(excluded.filetypes, filetype) then
		return false
	end

	local bufname = api.nvim_buf_get_name(buf)
	for _, pattern in ipairs(excluded.bufnames) do
		if bufname:match(pattern) then
			return false
		end
	end

	return true
end

--- Content windows of a tabpage, ordered by flow.
---@param tabpage? integer Defaults to the current tabpage
---@return integer[]
function M.list(tabpage)
	local flow = config.get().windows.flow
	local row_sign = flow.vertical == "below" and 1 or -1
	local col_sign = flow.horizontal == "right" and 1 or -1

	local windows = {}
	local positions = {}
	for _, win in ipairs(api.nvim_tabpage_list_wins(tabpage or 0)) do
		if M.is_content(win) then
			windows[#windows + 1] = win
			positions[win] = fn.win_screenpos(win)
		end
	end

	table.sort(windows, function(a, b)
		local pa, pb = positions[a], positions[b]
		if pa[1] ~= pb[1] then
			return (pa[1] - pb[1]) * row_sign < 0
		end
		return (pa[2] - pb[2]) * col_sign < 0
	end)

	return windows
end

---@param win? integer Defaults to the current window
---@return integer|nil
function M.index_of(win)
	win = win or api.nvim_get_current_win()
	for index, candidate in ipairs(M.list()) do
		if candidate == win then
			return index
		end
	end
	return nil
end

---@param win integer
---@return { buf: integer, view: table }
local function window_state(win)
	return {
		buf = api.nvim_win_get_buf(win),
		view = api.nvim_win_call(win, fn.winsaveview),
	}
end

---@param win integer
---@param state { buf: integer, view: table }
local function apply_state(win, state)
	api.nvim_win_set_buf(win, state.buf)
	api.nvim_win_call(win, function()
		fn.winrestview(state.view)
	end)
end

---@param n integer
---@return boolean focused Whether window n existed
function M.focus(n)
	local target = M.list()[n]
	if not target then
		return false
	end
	api.nvim_set_current_win(target)
	return true
end

--- Create one window anchored at the current window, on the flow side.
--- Falls back to the last indexed window when focus is in an excluded window.
---@param orientation "vsplit"|"split"
---@return integer|nil win The created window
function M.create(orientation)
	local windows_config = config.get().windows
	local windows = M.list()

	if #windows >= windows_config.max then
		notify.info(("All %d windows are in use"):format(windows_config.max))
		return nil
	end

	local anchor = api.nvim_get_current_win()
	if not M.is_content(anchor) and windows[#windows] then
		anchor = windows[#windows]
		api.nvim_set_current_win(anchor)
	end

	-- Explicit modifiers keep creation identical under any 'splitright'/'splitbelow'.
	local side
	if orientation == "vsplit" then
		side = windows_config.flow.horizontal == "right" and "rightbelow" or "leftabove"
	else
		side = windows_config.flow.vertical == "below" and "rightbelow" or "leftabove"
	end

	local ok, err = pcall(vim.cmd, side .. " " .. orientation)
	if not ok then
		notify.error("Could not create window: " .. err)
		return nil
	end
	vim.cmd("enew")

	return api.nvim_get_current_win()
end

--- Insert the current window's content at index n; everything between shifts.
---@param n integer
function M.move(n)
	local windows = M.list()
	local from = M.index_of()

	if not from then
		notify.info("The current window is not indexed")
		return
	end
	if not windows[n] then
		notify.info(("Window %d does not exist"):format(n))
		return
	end
	if from == n then
		return
	end

	local step = from < n and 1 or -1
	local carried = window_state(windows[from])
	-- Each frame reads from the frame ahead, so reads always precede writes.
	for i = from, n - step, step do
		apply_state(windows[i], window_state(windows[i + step]))
	end
	apply_state(windows[n], carried)

	api.nvim_set_current_win(windows[n])
end

--- Exchange the current window's content with window n.
---@param n integer
function M.swap(n)
	local windows = M.list()
	local from = M.index_of()

	if not from then
		notify.info("The current window is not indexed")
		return
	end
	if not windows[n] then
		notify.info(("Window %d does not exist"):format(n))
		return
	end
	if from == n then
		return
	end

	local ours = window_state(windows[from])
	apply_state(windows[from], window_state(windows[n]))
	apply_state(windows[n], ours)

	api.nvim_set_current_win(windows[n])
end

--- Close window n. Never quits Neovim; never discards buffer changes.
---@param n integer
---@param save? boolean Write the buffer before closing
function M.close(n, save)
	local target = M.list()[n]
	if not target then
		notify.info(("Window %d does not exist"):format(n))
		return
	end

	if save then
		local ok, err = pcall(api.nvim_win_call, target, function()
			vim.cmd("silent write")
		end)
		if not ok then
			notify.error(("Window %d was not closed, write failed: %s"):format(n, err))
			return
		end
	end

	local origin = api.nvim_get_current_win()
	local ok, err = pcall(api.nvim_win_close, target, true)
	if not ok then
		notify.info(("Window %d cannot be closed: %s"):format(n, err))
		return
	end

	if origin ~= target and api.nvim_win_is_valid(origin) then
		api.nvim_set_current_win(origin)
	end
end

--- Which axes the window can meaningfully resize on.
---@param win integer
---@return boolean horizontal, boolean vertical
local function sibling_axes(win)
	local horizontal, vertical = false, false
	local function walk(node)
		if node[1] == "leaf" then
			return node[2] == win
		end
		for _, child in ipairs(node[2]) do
			if walk(child) then
				if #node[2] > 1 then
					if node[1] == "row" then
						horizontal = true
					else
						vertical = true
					end
				end
				return true
			end
		end
		return false
	end
	walk(fn.winlayout())
	return horizontal, vertical
end

--- Nudge the current window in whichever dimensions have siblings.
---@param kind "grow"|"shrink"
function M.resize_step(kind)
	local sign = kind == "grow" and 1 or -1
	local horizontal, vertical = sibling_axes(api.nvim_get_current_win())
	if horizontal then
		vim.cmd(("vertical resize %+d"):format(sign * 3))
	end
	if vertical then
		vim.cmd(("resize %+d"):format(sign * 2))
	end
end

--- Close every content window except the current one.
function M.only()
	local current = api.nvim_get_current_win()
	if not M.is_content(current) then
		notify.info("The current window is not indexed")
		return
	end

	for _, win in ipairs(M.list()) do
		if win ~= current then
			pcall(api.nvim_win_close, win, true)
		end
	end
end

return M
