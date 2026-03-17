-- Localized vim variables
local keymap = vim.keymap

local M = {}

---@class KeymapSpec
---@field modes? string[] The keymap modes (default: { "n", "v" })
---@field key string The keymap configuration key
---@field func function The function to call
---@field desc string The keymap description

--- Register a keymap
---@param keymaps (WindWindowsKeymaps|WindClipboardKeymaps)? User keymap configuration
---@param spec KeymapSpec Keymap specification
---@return nil
function M.register(keymaps, spec)
	if keymaps == nil or keymaps == false then
		return
	end

	local key, func, desc = spec.key, spec.func, spec.desc

	if keymaps[key] then
		keymap.set(spec.modes or { "n", "v" }, keymaps[key], func, {
			desc = desc,
			noremap = true,
			silent = true,
		})
	end
end

--- Register a dynamic keymap
---@param keymaps (WindWindowsKeymaps|WindClipboardKeymaps)? User keymap configuration
---@param spec KeymapSpec Keymap specification
---@param index number The index of the keymap
---@return nil
function M.register_dynamic(keymaps, spec, index)
	if keymaps == nil or keymaps == false then
		return
	end

	local key, func, desc = spec.key, spec.func, spec.desc

	if keymaps[key] then
		keymap.set(spec.modes or { "n", "v" }, keymaps[key] .. index, func, {
			desc = desc,
			noremap = true,
			silent = true,
		})
	end
end

return M
