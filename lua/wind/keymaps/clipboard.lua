-- Local modules
local clipboard = require("wind.clipboard")
local keymaps = require("wind.utils.keymaps")

local M = {}

--- Setup function to create keymaps
---@param clipboard_config WindClipboardConfig
---@return nil
function M.setup(clipboard_config)
	-- Check if keymaps are enabled
	local keymaps_config = clipboard_config.keymaps
	if keymaps_config == false then
		return
	end

	-- Yank current window
	keymaps.register(keymaps_config, {
		key = "yank_current_window",
		func = function()
			clipboard.yank_with_path()
		end,
		desc = "Yank current window with path",
	})

	-- Yank current window in AI format
	keymaps.register(keymaps_config, {
		key = "yank_current_window_ai",
		func = function()
			clipboard.yank_current_window_ai()
		end,
		desc = "Yank current window in AI format",
	})

	-- Yank windows in AI format
	keymaps.register(keymaps_config, {
		key = "yank_windows_ai",
		func = function()
			clipboard.yank_windows_ai()
		end,
		desc = "Yank windows in AI format",
	})

	-- Yank filename
	keymaps.register(keymaps_config, {
		key = "yank_filename",
		func = function()
			clipboard.yank_filename()
		end,
		desc = "Yank filename",
	})
end

return M
