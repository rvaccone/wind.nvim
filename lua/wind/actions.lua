local api = vim.api

local engine = require("wind.engine")
local notify = require("wind.notify")
local snapshot = require("wind.snapshot")
local zoom = require("wind.zoom")

local M = {}

local HISTORY_LIMIT = 100

---@type table<integer, { type: string, before: WindSnapshotNode|nil, after: WindSnapshotNode|nil }[]>
local histories = {}

---@return { type: string, before: WindSnapshotNode|nil, after: WindSnapshotNode|nil }[]
function M.history()
	local tab = api.nvim_get_current_tabpage()
	histories[tab] = histories[tab] or {}
	return histories[tab]
end

--- Run a structural mutation and record it. Every layout change in the
--- plugin flows through here — history and drift depend on it.
---@param kind string
---@param mutate fun()
local function record(kind, mutate)
	local history = M.history()
	local before = snapshot.capture()

	local ok, err = pcall(mutate)
	if not ok then
		notify.error(("%s failed: %s"):format(kind, err))
		return
	end

	history[#history + 1] = { type = kind, before = before, after = snapshot.capture() }
	if #history > HISTORY_LIMIT then
		table.remove(history, 1)
	end
end

---@return boolean
local function layout_locked()
	if zoom.active() then
		notify.info("the layout is still while zoomed")
		return true
	end
	return false
end

--- Focus window n; when it doesn't exist, create one window anchored at the
--- current window. While zoomed, moves the lens instead.
---@param n integer
---@param orientation "vsplit"|"split"
function M.focus_or_create(n, orientation)
	if zoom.active() then
		zoom.lens_focus(n)
		return
	end

	if engine.focus(n) then
		return
	end

	record("create", function()
		local win = engine.create(orientation)
		if win then
			local index = engine.index_of(win)
			if index and index ~= n then
				notify.info(("created window %d"):format(index))
			end
		end
	end)
end

---@param n integer
function M.move(n)
	if layout_locked() then
		return
	end
	record("move", function()
		engine.move(n)
	end)
end

---@param n integer
function M.swap(n)
	if layout_locked() then
		return
	end
	record("swap", function()
		engine.swap(n)
	end)
end

---@param n integer
function M.close(n)
	if layout_locked() then
		return
	end
	record("close", function()
		engine.close(n)
	end)
end

---@param n integer
function M.save_close(n)
	if layout_locked() then
		return
	end
	record("save_close", function()
		engine.close(n, true)
	end)
end

function M.only()
	if layout_locked() then
		return
	end
	record("only", function()
		engine.only()
	end)
end

function M.zoom()
	zoom.toggle()
end

function M.reveal()
	require("wind.reveal").show({ manual = true })
end

return M
