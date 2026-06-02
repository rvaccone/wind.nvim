-- Localized vim variables
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local log = vim.log
local o = vim.o
local tbl_contains = vim.tbl_contains

-- Local modules
local config = require("wind.config")
local notifications = require("wind.utils.notifications")

local M = {}

M._windows_config = nil
M._maximize_state = nil

--- Setup function to receive the merged config
function M.setup(windows_config)
	M._windows_config = windows_config
end

--- Get the current configuration
function M.get_config()
	return M._windows_config or config.get_section("windows")
end

--- Check if a buffer name matches any excluded pattern
---@param bufname string The buffer name to check
---@param windows_config WindWindowsConfig
---@return boolean
local function matches_excluded_bufname(bufname, windows_config)
	for _, pattern in ipairs(windows_config.excluded_bufnames or {}) do
		if bufname:match(pattern) then
			return true
		end
	end
	return false
end

--- Check if a window should be included in Wind's content index.
---@param window integer
---@param windows_config WindWindowsConfig
---@return boolean
local function is_content_window(window, windows_config)
	if not api.nvim_win_is_valid(window) then
		return false
	end

	if api.nvim_win_get_config(window).relative ~= "" then
		return false
	end

	local buf = api.nvim_win_get_buf(window)
	local bufname = api.nvim_buf_get_name(buf)
	local filetype = api.nvim_get_option_value("filetype", { buf = buf })

	return not tbl_contains(windows_config.excluded_filetypes or {}, filetype)
		and not matches_excluded_bufname(bufname, windows_config)
end

--- Returns a list of all editor windows
---@return table
function M.list_content_windows()
	local windows_config = M.get_config()

	local windows = api.nvim_tabpage_list_wins(0)
	local editor_windows = {}

	for _, window in ipairs(windows) do
		if is_content_window(window, windows_config) then
			table.insert(editor_windows, window)
		end
	end

	table.sort(editor_windows, function(left, right)
		local left_position = fn.win_screenpos(left)
		local right_position = fn.win_screenpos(right)

		if left_position[1] == right_position[1] then
			return left_position[2] < right_position[2]
		end

		return left_position[1] < right_position[1]
	end)

	return editor_windows
end

--- Get the current window's index in the editor windows list
---@return number|nil current_window_index The 1-based index, or nil if not found
local function get_current_window_index()
	local editor_windows = M.list_content_windows()
	local current_window = api.nvim_get_current_win()

	for i, window in ipairs(editor_windows) do
		if window == current_window then
			return i
		end
	end

	return nil
end

--- Creates a window before the current window
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.create_window_before_current(split_direction)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()

	-- Prevent creating a new window if the maximum number of windows has been reached
	if #editor_windows >= windows_config.max_windows then
		notifications.notify_if_enabled(windows_config, "Maximum number of windows reached", log.levels.WARN)
		return
	end

	-- Split current window
	cmd(split_direction)
	cmd("enew")
end

--- Creates a window after the current window
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.create_window_after_current(split_direction)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()

	-- Prevent creating a new window if the maximum number of windows has been reached
	if #editor_windows >= windows_config.max_windows then
		notifications.notify_if_enabled(windows_config, "Maximum number of windows reached", log.levels.WARN)
		return
	end

	cmd(split_direction)
	if split_direction == "vsplit" then
		cmd("wincmd l")
	else
		cmd("wincmd j")
	end
	cmd("enew")
end

--- Focuses or creates a window before the current window
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.focus_or_create_window_before_current(split_direction)
	local windows_config = M.get_config()
	local current_win = api.nvim_get_current_win()

	if split_direction == "vsplit" then
		cmd("wincmd h")
	else
		cmd("wincmd k")
	end

	-- Check if we moved and the new window is valid
	if api.nvim_get_current_win() ~= current_win then
		-- If the new window is excluded, focus on the original window
		if is_content_window(api.nvim_get_current_win(), windows_config) then
			return
		end

		api.nvim_set_current_win(current_win)
	end

	M.create_window_before_current(split_direction)
end

--- Focuses or creates a window after the current window
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.focus_or_create_window_after_current(split_direction)
	local windows_config = M.get_config()
	local current_win = api.nvim_get_current_win()

	if split_direction == "vsplit" then
		cmd("wincmd l")
	else
		cmd("wincmd j")
	end

	-- Check if we moved and the new window is valid
	if api.nvim_get_current_win() ~= current_win then
		-- If the new window is excluded, focus on the original window
		if is_content_window(api.nvim_get_current_win(), windows_config) then
			return
		end

		api.nvim_set_current_win(current_win)
	end

	M.create_window_after_current(split_direction)
end

--- Creates a window at the end of the editor window list
---@param split_direction "vsplit"|"split" The split direction to use when creating a new window
---@return nil
function M.create_window(split_direction)
	local windows_config = M.get_config()
	local editor_windows = M.list_content_windows()

	-- Prevent creating a new window if the maximum number of windows has been reached
	if #editor_windows >= windows_config.max_windows then
		notifications.notify_if_enabled(windows_config, "Maximum number of windows reached", log.levels.WARN)
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

		local success, result = pcall(function()
			cmd(operation)
		end)
		if not success then
			notifications.notify_if_enabled(windows_config, "Error operating on window: " .. result, log.levels.ERROR)
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
	local current_window_index = get_current_window_index()
	if not current_window_index then
		notifications.notify_if_enabled(windows_config, "Current window is not a valid editor window", log.levels.WARN)
		return
	end

	-- Get the actual target window index
	local actual_target_index = windows_config.zero_based_indexing and (target_window_number + 1)
		or target_window_number

	-- Check if target window exists
	if actual_target_index > #editor_windows or actual_target_index < 1 then
		notifications.notify_if_enabled(
			windows_config,
			"Target window " .. target_window_number .. " does not exist",
			log.levels.WARN
		)
		return
	end

	-- Don't swap if it's the same window
	if current_window_index == actual_target_index then
		notifications.notify_if_enabled(windows_config, "Cannot swap window with itself")
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

	local current_user_index = windows_config.zero_based_indexing and (current_window_index - 1) or current_window_index
	notifications.notify_if_enabled(
		windows_config,
		"Swapped window " .. current_user_index .. " with window " .. target_window_number
	)
end

--- Toggle maximize current window
function M.toggle_maximize()
	if M._maximize_state then
		local maximize_state = M._maximize_state

		o.showtabline = maximize_state.showtabline

		if maximize_state.maximized_tab and api.nvim_tabpage_is_valid(maximize_state.maximized_tab) then
			api.nvim_set_current_tabpage(maximize_state.maximized_tab)

			local success, result = pcall(cmd, "tabclose")
			if not success then
				notifications.notify_if_enabled(
					M.get_config(),
					"Error restoring maximized window: " .. result,
					log.levels.ERROR
				)
				return
			end
		end

		M._maximize_state = nil

		if maximize_state.source_tab and api.nvim_tabpage_is_valid(maximize_state.source_tab) then
			api.nvim_set_current_tabpage(maximize_state.source_tab)
		end

		if maximize_state.source_win and api.nvim_win_is_valid(maximize_state.source_win) then
			pcall(api.nvim_set_current_win, maximize_state.source_win)
		end
	else
		-- Save state and maximize
		local maximize_state = {
			showtabline = o.showtabline,
			source_tab = api.nvim_get_current_tabpage(),
			source_win = api.nvim_get_current_win(),
		}
		o.showtabline = 0
		local success, result = pcall(cmd, "tab split")
		if not success then
			o.showtabline = maximize_state.showtabline
			notifications.notify_if_enabled(M.get_config(), "Error maximizing window: " .. result, log.levels.ERROR)
			return
		end

		maximize_state.maximized_tab = api.nvim_get_current_tabpage()
		M._maximize_state = maximize_state
	end
end

return M
