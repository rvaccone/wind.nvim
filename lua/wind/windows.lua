-- Localized vim variables
local api = vim.api
local cmd = vim.cmd
local log = vim.log
local notify = vim.notify
local tbl_contains = vim.tbl_contains

-- Local modules
local config = require("wind.config")

local M = {}

M._windows_config = nil

--- Setup function to receive the merged config
function M.setup(windows_config)
	M._windows_config = windows_config
end

--- Get the current configuration
function M.get_config()
	return M._windows_config or config.get_section("windows")
end

--- Returns a list of all editor windows
---@return table
function M.list_content_windows()
	local windows_config = M.get_config()

	local windows = api.nvim_list_wins()
	local editor_windows = {}

	for _, window in ipairs(windows) do
		local buf = api.nvim_win_get_buf(window)

		if buf and buf > 0 then
			local filetype = api.nvim_get_option_value("filetype", { buf = buf })

			if not tbl_contains(windows_config.excluded_filetypes, filetype) then
				table.insert(editor_windows, window)
			end
		end
	end

	return editor_windows
end

--- Creates a window at the end of the editor window list
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.create_window(split_direction)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()

	-- Prevent creating a new window if the maximum number of windows has been reached
	if #editor_windows >= windows_config.max_windows then
		if windows_config.notify ~= false then
			notify("Maximum number of windows reached", log.levels.WARN)
		end
		return
	end

	if #editor_windows > 0 then
		api.nvim_set_current_win(editor_windows[#editor_windows])
	end

	cmd(split_direction)
	if split_direction == "vsplit" then
		cmd("wincmd l")
	else
		cmd("wincmd j")
	end
	cmd("enew")
end

--- Focuses or creates a window at the end of the editor window list
---@param window_number number The window number to focus or create (1-based indexed)
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.focus_or_create_window(window_number, split_direction)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()

	-- Convert window number to actual index
	local actual_index = windows_config.zero_based_indexing and (window_number + 1) or window_number

	-- If the requested window exists, focus it
	if actual_index <= #editor_windows and actual_index >= 1 then
		api.nvim_set_current_win(editor_windows[actual_index])
		return
	end

	-- Otherwise, create a new window
	M.create_window(split_direction)
end

--- Executes a command on a window
---@param window_number number The window number to operate on
---@param operation string The command to execute on the window
---@return nil
function M.operate_on_window(window_number, operation)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()

	-- Get the actual target window index
	local actual_index = windows_config.zero_based_indexing and (window_number + 1) or window_number

	if actual_index >= 1 and actual_index <= #editor_windows then
		api.nvim_set_current_win(editor_windows[actual_index])

		local success, result = pcall(cmd, operation)
		if not success and windows_config.notify ~= false then
			notify("Error operating on window: " .. result, log.levels.ERROR)
		end
	end
end

--- Swaps the buffer of the current window with the buffer of the specified window
---@param target_window_number number The window number to swap with (1-based indexed)
---@return nil
function M.swap_window(target_window_number)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()
	local current_window = api.nvim_get_current_win()

	-- Find the current window's index in the editor windows list
	local current_window_index = nil
	for i, window in ipairs(editor_windows) do
		if window == current_window then
			current_window_index = i
			break
		end
	end

	-- Check if current window is a valid editor window
	if not current_window_index then
		if windows_config.notify ~= false then
			notify("Current window is not a valid editor window", log.levels.WARN)
		end
		return
	end

	-- Get the actual target window index
	local actual_target_index = windows_config.zero_based_indexing and (target_window_number + 1)
		or target_window_number

	-- Check if target window exists
	if actual_target_index > #editor_windows or actual_target_index < 1 then
		if windows_config.notify ~= false then
			notify("Target window " .. target_window_number .. " does not exist", log.levels.WARN)
		end
		return
	end

	-- Don't swap if it's the same window
	if current_window_index == actual_target_index then
		if windows_config.notify ~= false then
			notify("Cannot swap window with itself", log.levels.INFO)
		end
		return
	end

	local target_window = editor_windows[actual_target_index]

	-- Get buffers from both windows
	local current_buffer = api.nvim_win_get_buf(current_window)
	local target_buffer = api.nvim_win_get_buf(target_window)

	-- Get cursor positions from both windows
	local current_cursor = api.nvim_win_get_cursor(current_window)
	local target_cursor = api.nvim_win_get_cursor(target_window)

	-- Swap the buffers
	api.nvim_win_set_buf(current_window, target_buffer)
	api.nvim_win_set_buf(target_window, current_buffer)

	-- Restore cursor positions
	pcall(api.nvim_win_set_cursor, current_window, target_cursor)
	pcall(api.nvim_win_set_cursor, target_window, current_cursor)

	-- Focus on the target window after swapping
	api.nvim_set_current_win(target_window)

	if windows_config.notify ~= false then
		local current_user_index = windows_config.zero_based_indexing and (current_window_index - 1)
			or current_window_index
		notify("Swapped window " .. current_user_index .. " with window " .. target_window_number, log.levels.INFO)
	end
end

return M
