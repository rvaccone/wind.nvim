-- Local modules
local keymaps = require("wind.utils.keymaps")
local windows = require("wind.windows")

local M = {}

--- Setup function to create keymaps
---@param windows_config WindWindowsConfig
---@return nil
function M.setup(windows_config)
	-- Check if keymaps are enabled
	local keymaps_config = windows_config.keymaps
	if keymaps_config == false then
		return
	end

	-- Get the start and max index
	local start_index = windows_config.zero_based_indexing and 0 or 1
	local max_index = windows_config.zero_based_indexing and windows_config.max_windows - 1
		or windows_config.max_windows

	-- Create the dynamic keymaps
	for i = start_index, max_index do
		-- Focus or create horizontal window
		keymaps.register_dynamic(keymaps_config, {
			key = "focus_or_create_horizontal_window",
			func = function()
				windows.focus_or_create_window(i, "vsplit")
			end,
			desc = "Focus or create horizontal window " .. i,
		}, i)

		-- Focus or create vertical window
		keymaps.register_dynamic(keymaps_config, {
			key = "focus_or_create_vertical_window",
			func = function()
				windows.focus_or_create_window(i, "split")
			end,
			desc = "Focus or create vertical window " .. i,
		}, i)

		-- Swap window
		keymaps.register_dynamic(keymaps_config, {
			key = "swap_window",
			func = function()
				windows.swap_window(i)
			end,
			desc = "Swap current window with window " .. i,
		}, i)

		-- Close window
		keymaps.register_dynamic(keymaps_config, {
			key = "close_window",
			func = function()
				windows.operate_on_window(i, "q!")
			end,
			desc = "Close window " .. i,
		}, i)

		-- Close window with save
		keymaps.register_dynamic(keymaps_config, {
			key = "close_window_with_save",
			func = function()
				windows.operate_on_window(i, "wq!")
			end,
			desc = "Close window " .. i .. " with save",
		}, i)
	end

	-- Toggle maximize
	keymaps.register(keymaps_config, {
		key = "toggle_maximize",
		func = function()
			windows.toggle_maximize()
		end,
		desc = "Toggle maximize",
	})

	-- Focus or create directional window
	keymaps.register(keymaps_config, {
		key = "focus_or_create_left_window",
		func = function()
			windows.focus_or_create_window_before_current("vsplit")
		end,
		desc = "Focus or create window to the left of the current",
	})

	keymaps.register(keymaps_config, {
		key = "focus_or_create_below_window",
		func = function()
			windows.focus_or_create_window_after_current("split")
		end,
		desc = "Focus or create window below the current",
	})

	keymaps.register(keymaps_config, {
		key = "focus_or_create_above_window",
		func = function()
			windows.focus_or_create_window_before_current("split")
		end,
		desc = "Focus or create window above the current",
	})

	keymaps.register(keymaps_config, {
		key = "focus_or_create_right_window",
		func = function()
			windows.focus_or_create_window_after_current("vsplit")
		end,
		desc = "Focus or create window to the right of the current",
	})

	-- Create directional window
	keymaps.register(keymaps_config, {
		key = "create_left_window",
		func = function()
			windows.create_window_before_current("vsplit")
		end,
		desc = "Create window to the left of the current",
	})

	keymaps.register(keymaps_config, {
		key = "create_below_window",
		func = function()
			windows.create_window_after_current("split")
		end,
		desc = "Create window below the current",
	})

	keymaps.register(keymaps_config, {
		key = "create_above_window",
		func = function()
			windows.create_window_before_current("split")
		end,
		desc = "Create window above the current",
	})

	keymaps.register(keymaps_config, {
		key = "create_right_window",
		func = function()
			windows.create_window_after_current("vsplit")
		end,
		desc = "Create window to the right of the current",
	})
end

return M
