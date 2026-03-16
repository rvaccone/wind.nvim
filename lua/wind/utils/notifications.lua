-- Localized vim variables
local notify = vim.notify
local log = vim.log

local M = {}

--- Notify if enabled
---@param config table
---@param message string
---@param level integer|nil
---@return nil
function M.notify_if_enabled(config, message, level)
	if config.notify ~= false then
		notify(message, level or log.levels.INFO)
	end
end

return M
