-- Localized vim variables
local api = vim.api
local fn = vim.fn
local keymap = vim.keymap
local log = vim.log
local notify = vim.notify
local pesc = vim.pesc

local M = {}

--- Return OS path separator
---@return string
function M.path_sep()
	return package.config:sub(1, 1)
end

--- Get a relative file path from a directory
---@param abs_path string
---@param cwd string|nil
---@return string
function M.relativize_path(abs_path, cwd)
	-- Handle empty or no absolute path
	if not abs_path or abs_path == "" then
		return "[No Name]"
	end

	-- Determine the prefix for the current directory
	local base = cwd or fn.getcwd()
	local sep = path_sep()
	local prefix = base .. sep

	-- Strip the prefix from the absolute path
	local stripped = abs_path:gsub("^" .. pesc(prefix), "")
	return stripped ~= abs_path and stripped or abs_path
end

--- Compose buffer content with its relative file path
---@param cwd string|nil
---@param buf integer|nil
---@return string
function M.compose_buffer_content_with_path(cwd, buf)
	buf = buf or 0
	local buffer_content = api.nvim_buf_get_lines(buf, 0, -1, false)
	local abs_path = api.nvim_buf_get_name(buf)
	local display_path = relativize_path(abs_path, cwd)
	return string.format("%s:\n%s", display_path, table.concat(buffer_content, "\n"))
end
