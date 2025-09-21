-- Localized vim variables
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local log = vim.log
local notify = vim.notify
local tbl_contains = vim.tbl_contains

-- Local modules
local config = require("wind.config")
local files = require("wind.utils.files")
local windows = require("wind.windows")

local M = {}

M._clipboard_config = nil

--- Setup function to receive the merged config
function M.setup(clipboard_config)
	M._clipboard_config = clipboard_config
end

--- Get the current configuration
function M.get_config()
	return M._clipboard_config or config.get_section("clipboard")
end

--- Yank the entire buffer and append the file path
function M.yank_with_path()
	local clipboard_config = M.get_config()
	local combined_content = files.compose_buffer_content_with_path(nil, 0)
	fn.setreg("+", combined_content)

	-- Notify the user
	if clipboard_config.notify ~= false then
		notify(string.format("Copied %d lines to clipboard with path", api.nvim_buf_line_count(0)), log.levels.INFO)
	end
end

--- Compose an AI-friendly block for a given window
---@param win integer|nil
---@param cwd string|nil
---@return string
local function compose_block_for_window(win, cwd)
	-- Get the buffer content and the path
	local target_win = win or api.nvim_get_current_win()
	local buf = api.nvim_win_get_buf(target_win)
	local lines_tbl = api.nvim_buf_get_lines(buf, 0, -1, false)
	local abs_path = api.nvim_buf_get_name(buf)
	local relpath = files.relativize_path(abs_path, cwd)
	local filetype = api.nvim_get_option_value("filetype", { buf = buf }) or ""

	-- Compose the block
	return table.concat({
		"=== FILE BEGIN ===",
		"Path: " .. relpath,
		"Filetype: " .. filetype,
		"Lines: " .. tostring(#lines_tbl),
		"--- CONTENT ---",
		table.concat(lines_tbl, "\n"),
		"=== FILE END ===",
	}, "\n")
end

--- Yank buffer contents and file paths for all open windows
function M.yank_all_with_path()
	local clipboard_config = M.get_config()
	local editor_windows = windows.list_content_windows()

	-- Prevent yanking if there are no windows
	if #editor_windows == 0 then
		if clipboard_config.notify ~= false then
			notify("No content windows to yank", log.levels.WARN)
		end
		return
	end

	local original_win = api.nvim_get_current_win()
	local cwd = fn.getcwd()
	local blocks = {}
	local total_lines = 0

	-- Iterate in window index order and compose blocks
	for i = 1, #editor_windows do
		local win = editor_windows[i]
		if api.nvim_win_is_valid(win) then
			table.insert(blocks, compose_block_for_window(win, cwd))
			total_lines = total_lines + api.nvim_buf_line_count(api.nvim_win_get_buf(win))
		end
	end

	-- Restore original window focus
	if original_win and api.nvim_win_is_valid(original_win) then
		api.nvim_set_current_win(original_win)
	end

	-- Notify the user
	fn.setreg("+", table.concat(blocks, "\n"))
	if clipboard_config.notify ~= false then
		notify(
			string.format("Copied %d windows with %d total lines to clipboard with paths", #blocks, total_lines),
			log.levels.INFO
		)
	end
end

--- Yank the filename of the current buffer
function M.yank_filename()
	local clipboard_config = M.get_config()
	local filename = fn.expand("%:t")

	if filename and filename ~= "" then
		fn.setreg("+", filename)
		if clipboard_config.notify ~= false then
			notify(string.format("Copied filename %s to clipboard", filename), log.levels.INFO)
		end
	else
		if clipboard_config.notify ~= false then
			notify("No filename found", log.levels.ERROR)
		end
	end
end

return M
