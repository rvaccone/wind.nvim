local api = vim.api

local engine = require("wind.engine")
local notify = require("wind.notify")
local snapshot = require("wind.snapshot")
local zoom = require("wind.zoom")

local M = {}

local HISTORY_LIMIT = 100

---@class WindAction
---@field type string
---@field before WindSnapshotNode|nil
---@field after WindSnapshotNode|nil

---@type table<integer, { entries: WindAction[], pointer: integer }>
local histories = {}

local function history()
	local tab = api.nvim_get_current_tabpage()
	histories[tab] = histories[tab] or { entries = {}, pointer = 0 }
	return histories[tab]
end

---@return WindAction[]
function M.history()
	return history().entries
end

---@return integer
function M.history_pointer()
	return history().pointer
end

--- Run a structural mutation and record it. Every layout change in the
--- plugin flows through here — history, undo, and drift depend on it.
---@param kind string
---@param mutate fun()
local function record(kind, mutate)
	local h = history()
	local before = snapshot.capture()

	local ok, err = pcall(mutate)
	if not ok then
		notify.error(("%s failed: %s"):format(kind, err))
		return
	end

	for i = #h.entries, h.pointer + 1, -1 do
		h.entries[i] = nil
	end
	h.entries[#h.entries + 1] = { type = kind, before = before, after = snapshot.capture() }
	if #h.entries > HISTORY_LIMIT then
		table.remove(h.entries, 1)
	end
	h.pointer = #h.entries
end

--- Breaths record their jumps through the same dispatcher.
---@param kind string
---@param mutate fun()
function M.record_jump(kind, mutate)
	record(kind, mutate)
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
	require("wind.breath").set_alternate()
	record("only", function()
		engine.only()
	end)
end

--- Walk the layout history backward. Never touches buffer contents.
---@param count? integer
function M.undo(count)
	if layout_locked() then
		return
	end
	local h = history()
	local remaining = math.max(1, count or 1)
	local applied = 0
	while remaining > 0 and h.pointer > 0 do
		local entry = h.entries[h.pointer]
		h.pointer = h.pointer - 1
		if snapshot.restore(entry.before) then
			applied = applied + 1
		end
		remaining = remaining - 1
	end
	if applied == 0 then
		notify.info("nothing to undo")
	end
end

---@param count? integer
function M.redo(count)
	if layout_locked() then
		return
	end
	local h = history()
	local remaining = math.max(1, count or 1)
	local applied = 0
	while remaining > 0 and h.pointer < #h.entries do
		h.pointer = h.pointer + 1
		if snapshot.restore(h.entries[h.pointer].after) then
			applied = applied + 1
		end
		remaining = remaining - 1
	end
	if applied == 0 then
		notify.info("nothing to redo")
	end
end

function M.equalize()
	if layout_locked() then
		return
	end
	record("equalize", function()
		vim.cmd("wincmd =")
	end)
end

--- A whole grow/shrink session commits as one action.
---@param session fun()
function M.resize_session(session)
	if layout_locked() then
		return
	end
	record("resize", session)
end

function M.zoom()
	zoom.toggle()
end

function M.reveal()
	require("wind.reveal").show({ manual = true })
end

return M
