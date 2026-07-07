local health = vim.health

local M = {}

function M.check()
	health.start("wind.nvim")

	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim >= 0.10")
	else
		health.error("wind.nvim requires Neovim 0.10 or newer")
	end

	local config = require("wind.config")
	if config._config then
		health.ok("setup() was called and the configuration is valid")
	else
		health.warn("setup() has not been called — running on defaults")
	end

	local keymaps = config.get().keymaps
	if keymaps == false then
		health.ok("keymaps are disabled by configuration")
	elseif keymaps.prefix:find("<[Ll]eader>") and (vim.g.mapleader == nil or vim.g.mapleader == "") then
		health.warn("g:mapleader is unset — the prefix resolves to backslash")
	else
		health.ok(("keymap prefix: %s"):format(keymaps.prefix))
	end

	if pcall(require, "which-key") then
		health.ok("which-key detected: bare-prefix badges appear right at reveal.delay_ms")
	else
		health.info("no which-key detected: bare-prefix badges appear when the pending mapping resolves ('timeoutlen')")
	end

	local windows = require("wind.engine").list()
	health.info(("%d content window(s) currently indexed"):format(#windows))
	health.info(("%d breath(s) held"):format(#require("wind.breath").entries()))
	health.info(("%d layout action(s) in this tabpage's history"):format(#require("wind.actions").history()))
end

return M
