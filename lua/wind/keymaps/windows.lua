-- Localized vim variables
local keymap = vim.keymap

-- Local modules
local windows = require("wind.windows")

local M = {}

function M.setup(config)
	local keymaps_config = config["keymaps"] or {}
	local windows_config = config["windows"] or {}

	-- Check if keymaps are enabled
	if windows_config.enable_window_keymaps == false then
		return
	end

	-- Get the start and max index
	local start_index = windows_config.zero_based_indexing and 0 or 1
	local max_index = windows_config.zero_based_indexing and windows_config.max_windows - 1
		or windows_config.max_windows

	-- Create the keymaps
	for i = start_index, max_index do
		-- Focus or create horizontal window
		if keymaps_config.focus_or_create_horizontal_window then
			keymap.set({ "n", "v" }, keymaps_config.focus_or_create_horizontal_window .. i, function()
				windows.focus_or_create_window(i, "vsplit")
			end, { desc = "Focus or create horizontal window " .. i, noremap = true, silent = true })
		end

		-- Focus or create vertical window
		if keymaps_config.focus_or_create_vertical_window then
			keymap.set({ "n", "v" }, keymaps_config.focus_or_create_vertical_window .. i, function()
				windows.focus_or_create_window(i, "split")
			end, { desc = "Focus or create vertical window " .. i, noremap = true, silent = true })
		end

		-- Swap window
		if keymaps_config.swap_window then
			keymap.set({ "n", "v" }, keymaps_config.swap_window .. i, function()
				windows.swap_window(i)
			end, { desc = "Swap current window with window " .. i, noremap = true, silent = true })
		end

		-- Close window
		if keymaps_config.close_window then
			keymap.set({ "n", "v" }, keymaps_config.close_window .. i, function()
				windows.operate_on_window(i, "q!")
			end, { desc = "Close window " .. i, noremap = true, silent = true })
		end

		-- Close window and swap
		if keymaps_config.close_window_and_swap then
			keymap.set({ "n", "v" }, keymaps_config.close_window_and_swap .. i, function()
				windows.operate_on_window(i, "wq!")
			end, { desc = "Close window " .. i .. " and swap", noremap = true, silent = true })
		end
	end
end

return M
