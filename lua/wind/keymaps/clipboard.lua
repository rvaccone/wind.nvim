-- Localized vim variables
local keymap = vim.keymap

-- Local modules
local clipboard = require("wind.clipboard")

local M = {}

function M.setup(config)
	local keymaps_config = config["keymaps"] or {}
	local clipboard_config = config["clipboard"] or {}

	-- Check if keymaps are enabled
	if clipboard_config.enable_clipboard_keymaps == false then
		return
	end

	-- Yank current window
	if keymaps_config.yank_current_window then
		keymap.set({ "n", "v" }, keymaps_config.yank_current_window, function()
			clipboard.yank_with_path()
		end, { desc = "Yank current window with path", noremap = true, silent = true })
	end

	-- Yank current window in AI format
	if keymaps_config.yank_current_window_ai then
		keymap.set({ "n", "v" }, keymaps_config.yank_current_window_ai, function()
			clipboard.yank_current_window_ai()
		end, { desc = "Yank current window in AI format", noremap = true, silent = true })
	end

	-- Yank windows in AI format
	if keymaps_config.yank_windows_ai then
		keymap.set({ "n", "v" }, keymaps_config.yank_windows_ai, function()
			clipboard.yank_windows_ai()
		end, { desc = "Yank windows in AI format", noremap = true, silent = true })
	end

	-- Yank filename
	if keymaps_config.yank_filename then
		keymap.set({ "n", "v" }, keymaps_config.yank_filename, function()
			clipboard.yank_filename()
		end, { desc = "Yank filename", noremap = true, silent = true })
	end
end

return M
