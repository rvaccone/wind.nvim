-- Localized vim variables
local keymap = vim.keymap

-- Local modules
local clipboard = require("wind.clipboard")

local M = {}

--- Setup function to create keymaps
---@param clipboard_config WindClipboardConfig
---@return nil
function M.setup(clipboard_config)
	-- Check if keymaps are enabled
	local keymaps = clipboard_config.keymaps
	if keymaps == false then
		return
	end

	-- Yank current window
	if keymaps.yank_current_window then
		keymap.set({ "n", "v" }, keymaps.yank_current_window, function()
			clipboard.yank_with_path()
		end, { desc = "Yank current window with path", noremap = true, silent = true })
	end

	-- Yank current window in AI format
	if keymaps.yank_current_window_ai then
		keymap.set({ "n", "v" }, keymaps.yank_current_window_ai, function()
			clipboard.yank_current_window_ai()
		end, { desc = "Yank current window in AI format", noremap = true, silent = true })
	end

	-- Yank windows in AI format
	if keymaps.yank_windows_ai then
		keymap.set({ "n", "v" }, keymaps.yank_windows_ai, function()
			clipboard.yank_windows_ai()
		end, { desc = "Yank windows in AI format", noremap = true, silent = true })
	end

	-- Yank filename
	if keymaps.yank_filename then
		keymap.set({ "n", "v" }, keymaps.yank_filename, function()
			clipboard.yank_filename()
		end, { desc = "Yank filename", noremap = true, silent = true })
	end
end

return M
