local config = require("wind.config")

local M = {}

local function map(lhs, rhs, desc)
	vim.keymap.set({ "n", "v" }, lhs, rhs, { desc = desc, silent = true })
end

--- Show badges, read one key, act. Owning the pending state is the only way
--- to guide it: keys inside a native pending mapping are invisible until
--- they resolve, so each digit family is a single trigger plus this loop.
---@param dispatch table<string, fun()>
local function guided(dispatch)
	local reveal = require("wind.reveal")
	reveal.show()
	local ok, char = pcall(vim.fn.getcharstr)
	reveal.hide()
	if not ok then
		return
	end
	local action = dispatch[char]
	if action then
		action()
	end
end

---@param on_digit fun(n: integer)
---@param extra? table<string, fun()>
---@return fun()
local function family(on_digit, extra)
	local dispatch = {}
	for n = 1, config.get().windows.max do
		dispatch[tostring(n)] = function()
			on_digit(n)
		end
	end
	for char, action in pairs(extra or {}) do
		dispatch[char] = action
	end
	return function()
		guided(dispatch)
	end
end

function M.setup()
	local keymaps = config.get().keymaps
	if keymaps == false then
		return
	end

	local actions = require("wind.actions")
	local prefix = keymaps.prefix
	local window = keymaps.window

	-- The reflex path stays native: no loop, no overhead, no reveal.
	for n = 1, config.get().windows.max do
		map(prefix .. n, function()
			actions.focus_or_create(n, "vsplit")
		end, "Focus or create window " .. n)
	end

	if window.stacked then
		map(
			prefix .. window.stacked,
			family(function(n)
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
	map(prefix .. window.namespace, family(actions.move, verbs), "Move window to 1-9")

	if window.swap then
		map(prefix .. window.swap, family(actions.swap), "Swap window with 1-9")
	end

	if window.close then
		map(prefix .. window.close, family(actions.close), "Close window 1-9")
	end

	if window.save_close then
		map(prefix .. window.save_close, family(actions.save_close), "Save and close window 1-9")
	end
end

return M
