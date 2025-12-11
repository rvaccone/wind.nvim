-- Local modules
local config = require("wind.config")
local clipboard = require("wind.clipboard")
local clipboard_keymaps = require("wind.keymaps.clipboard")
local windows = require("wind.windows")
local windows_keymaps = require("wind.keymaps.windows")

local wind = {}

--- Setup function that lazy.nvim will call
---@param opts WindConfig
---@return nil
function wind.setup(opts)
	-- Setup the config module
	config.setup(opts)

	-- Get config sections
	local clipboard_config = config.get_section("clipboard")
	local windows_config = config.get_section("windows")

	-- Pass the config to modules
	clipboard.setup(clipboard_config)
	windows.setup(windows_config)

	-- Setup keymaps
	if clipboard_config.keymaps ~= false then
		clipboard_keymaps.setup(clipboard_config)
	end

	if windows_config.keymaps ~= false then
		windows_keymaps.setup(windows_config)
	end
end

-- Export the module
return wind
