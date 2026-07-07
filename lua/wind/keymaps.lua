local config = require("wind.config")

local M = {}

local ESC = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)

local function map(lhs, rhs, desc)
	vim.keymap.set({ "n", "v" }, lhs, rhs, { desc = desc, silent = true })
end

---@type { action: fun(), skip: boolean }|nil
local dot = nil

--- Operatorfunc target for dot-repeat. The initial `g@l` is swallowed
--- because the action already ran when the key was pressed; only `.`
--- reaches the action.
function M.dot_repeat()
	if not dot then
		return
	end
	if dot.skip then
		dot.skip = false
		return
	end
	dot.action()
end

--- Make `.` repeat a wind action. The action itself already ran, so
--- correctness never depends on this; if `g@l` cannot apply (empty line),
--- only the repeat is lost.
---@param action fun()
local function arm_dot(action)
	if vim.api.nvim_get_mode().mode ~= "n" then
		return
	end
	dot = { action = action, skip = true }
	vim.o.operatorfunc = "v:lua.require'wind.keymaps'.dot_repeat"
	vim.api.nvim_feedkeys("g@l", "n", false)
end

--- Show guidance, read one key, act. Owning the pending state is the only
--- way to guide it: keys inside a native pending mapping are invisible
--- until they resolve, so each digit family is a trigger plus this loop.
--- Guidance appears only after a slight hesitation — muscle-memory speed
--- never sees it.
---@param dispatch table<string, fun(count: integer)>
---@param show fun()
local function guided(dispatch, show)
	local count = vim.v.count1
	local reveal = require("wind.reveal")

	-- Continuity: if a bare-prefix reveal was just on screen, keep guiding
	-- without a fresh delay instead of flickering out and back in.
	local delay = config.get().reveal.delay_ms
	local pending
	if delay > 0 and not reveal.recently_visible() then
		pending = vim.defer_fn(show, delay)
	else
		show()
	end

	local ok, char = pcall(vim.fn.getcharstr)
	if pending and not pending:is_closing() then
		pending:stop()
		pending:close()
	end
	reveal.hide()

	if not ok then
		return
	end
	local action = dispatch[char]
	if action then
		action(count)
	end
end

---@param max integer
---@param on_digit fun(n: integer)
---@param extra? table<string, fun(count: integer)>
---@return table<string, fun(count: integer)>
local function digits(max, on_digit, extra)
	local dispatch = {}
	for n = 1, max do
		dispatch[tostring(n)] = function()
			on_digit(n)
		end
	end
	for char, action in pairs(extra or {}) do
		dispatch[char] = action
	end
	return dispatch
end

--- Tap grow/shrink repeatedly; any other key leaves the submode and runs
--- normally. The whole session lands in history as a single action, and
--- `.` afterward repeats one step in the last direction.
---@param first "grow"|"shrink"
---@param grow_char string|false
---@param shrink_char string|false
local function resize_session(first, grow_char, shrink_char)
	local last = first
	require("wind.actions").resize_session(function()
		local engine = require("wind.engine")
		local step = first
		while true do
			engine.resize_step(step)
			last = step
			vim.cmd("redraw")
			local ok, char = pcall(vim.fn.getcharstr)
			if not ok or char == ESC then
				return
			end
			if char == grow_char or char == "+" then
				step = "grow"
			elseif char == shrink_char or char == "-" then
				step = "shrink"
			else
				vim.api.nvim_feedkeys(char, "m", false)
				return
			end
		end
	end)
	arm_dot(function()
		require("wind.actions").resize_session(function()
			require("wind.engine").resize_step(last)
		end)
	end)
end

function M.setup()
	local keymaps = config.get().keymaps
	if keymaps == false then
		return
	end

	local actions = require("wind.actions")
	local reveal = require("wind.reveal")
	local prefix = keymaps.prefix
	local window = keymaps.window
	local breath_keys = keymaps.breath
	local window_max = config.get().windows.max

	-- The reflex path stays native: no loop, no overhead, no reveal.
	for n = 1, window_max do
		map(prefix .. n, function()
			actions.focus_or_create(n, "vsplit")
		end, "Focus or create window " .. n)
	end

	local function family(lhs, dispatch, desc, show)
		map(lhs, function()
			guided(dispatch, show or reveal.show)
		end, desc)
	end

	if window.stacked then
		family(
			prefix .. window.stacked,
			digits(window_max, function(n)
				actions.focus_or_create(n, "split")
			end),
			"Focus or create stacked window 1-9"
		)
	end

	local verbs = {}
	if window.only then
		verbs[window.only] = actions.only
	end
	if window.zoom then
		verbs[window.zoom] = actions.zoom
	end
	if window.undo then
		verbs[window.undo] = function(count)
			actions.undo(count)
			arm_dot(function()
				actions.undo(count)
			end)
		end
	end
	if window.redo then
		verbs[window.redo] = function(count)
			actions.redo(count)
			arm_dot(function()
				actions.redo(count)
			end)
		end
	end
	if window.equalize then
		verbs[window.equalize] = actions.equalize
	end
	if window.grow then
		verbs[window.grow] = function()
			resize_session("grow", window.grow, window.shrink)
		end
	end
	if window.shrink then
		verbs[window.shrink] = function()
			resize_session("shrink", window.grow, window.shrink)
		end
	end
	family(prefix .. window.namespace, digits(window_max, actions.move, verbs), "Move window to 1-9")

	if window.swap then
		family(prefix .. window.swap, digits(window_max, actions.swap), "Swap window with 1-9")
	end

	if window.close then
		family(prefix .. window.close, digits(window_max, actions.close), "Close window 1-9")
	end

	if window.save_close then
		family(prefix .. window.save_close, digits(window_max, actions.save_close), "Save and close window 1-9")
	end

	-- Breaths: return by digit, verbs beside them, all behind one trigger.
	local breath = require("wind.breath")
	local breath_max = config.get().breaths.max

	local breath_verbs = {}
	if breath_keys.update then
		breath_verbs[breath_keys.update] = breath.update
	end
	if breath_keys.hold then
		breath_verbs[breath_keys.hold] = function()
			breath.hold()
		end
	end
	if breath_keys.alternate then
		breath_verbs[breath_keys.alternate] = breath.toggle_alternate
	end
	if breath_keys.release then
		breath_verbs[breath_keys.release] = breath.release_current
	end
	family(
		prefix .. breath_keys.namespace,
		digits(breath_max, breath.return_to, breath_verbs),
		"Breaths: return 1-9, update, hold, release",
		reveal.show_breaths
	)
end

return M
