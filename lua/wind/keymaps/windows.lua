-- Localized vim variables
local keymap = vim.keymap

-- Local modules
local windows = require("wind.windows")

local M = {}

--- Setup function to create keymaps
---@param windows_config WindWindowsConfig
---@return nil
function M.setup(windows_config)
	-- Check if keymaps are enabled
	local keymaps = windows_config.keymaps
	if keymaps == false then
		return
	end

	-- Get the start and max index
	local start_index = windows_config.zero_based_indexing and 0 or 1
	local max_index = windows_config.zero_based_indexing and windows_config.max_windows - 1
		or windows_config.max_windows

	-- Create the keymaps
	for i = start_index, max_index do
		-- Focus or create horizontal window
		if keymaps ~= nil and keymaps.focus_or_create_horizontal_window then
			keymap.set({ "n", "v" }, keymaps.focus_or_create_horizontal_window .. i, function()
				windows.focus_or_create_window(i, "vsplit")
			end, { desc = "Focus or create horizontal window " .. i, noremap = true, silent = true })
		end

		-- Focus or create vertical window
		if keymaps ~= nil and keymaps.focus_or_create_vertical_window then
			keymap.set({ "n", "v" }, keymaps.focus_or_create_vertical_window .. i, function()
				windows.focus_or_create_window(i, "split")
			end, { desc = "Focus or create vertical window " .. i, noremap = true, silent = true })
		end

		-- Swap window
		if keymaps ~= nil and keymaps.swap_window then
			keymap.set({ "n", "v" }, keymaps.swap_window .. i, function()
				windows.swap_window(i)
			end, { desc = "Swap current window with window " .. i, noremap = true, silent = true })
		end

		-- Close window
		if keymaps ~= nil and keymaps.close_window then
			keymap.set({ "n", "v" }, keymaps.close_window .. i, function()
				windows.operate_on_window(i, "q!")
			end, { desc = "Close window " .. i, noremap = true, silent = true })
		end

		-- Close window and swap
		if keymaps ~= nil and keymaps.close_window_and_swap then
			keymap.set({ "n", "v" }, keymaps.close_window_and_swap .. i, function()
				windows.operate_on_window(i, "wq!")
			end, { desc = "Close window " .. i .. " and swap", noremap = true, silent = true })
		end
	end
end

return M
