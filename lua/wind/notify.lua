local M = {}

local function send(msg, level)
	vim.notify(msg, level, { title = "wind" })
end

--- Informational notice, silenced by `windows.notify = false`.
---@param msg string
function M.info(msg)
	if require("wind.config").get().windows.notify then
		send(msg, vim.log.levels.INFO)
	end
end

---@param msg string
function M.warn(msg)
	send(msg, vim.log.levels.WARN)
end

---@param msg string
function M.error(msg)
	send(msg, vim.log.levels.ERROR)
end

return M
