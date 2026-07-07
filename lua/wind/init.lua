local M = {}

local subcommands = {
	reveal = function()
		require("wind.actions").reveal()
	end,
}

---@param opts WindConfig|nil
function M.setup(opts)
	require("wind.config").setup(opts)
	require("wind.keymaps").setup()
	require("wind.reveal").setup()
	require("wind.zoom").setup()

	vim.api.nvim_create_user_command("Wind", function(command)
		local name = command.fargs[1] or "reveal"
		local subcommand = subcommands[name]
		if subcommand then
			subcommand()
		else
			require("wind.notify").warn(("unknown subcommand: %s"):format(name))
		end
	end, {
		nargs = "*",
		complete = function()
			return vim.tbl_keys(subcommands)
		end,
		desc = "wind.nvim",
	})
end

--- Public API: destination-first window operations.
M.focus_or_create = function(n, orientation)
	require("wind.actions").focus_or_create(n, orientation or "vsplit")
end
M.move = function(n)
	require("wind.actions").move(n)
end
M.swap = function(n)
	require("wind.actions").swap(n)
end
M.close = function(n)
	require("wind.actions").close(n)
end
M.save_close = function(n)
	require("wind.actions").save_close(n)
end
M.only = function()
	require("wind.actions").only()
end
M.zoom = function()
	require("wind.actions").zoom()
end
M.reveal = function()
	require("wind.actions").reveal()
end

--- Ordered content windows — usable from statuslines and scripts.
M.list = function()
	return require("wind.engine").list()
end
M.index_of = function(win)
	return require("wind.engine").index_of(win)
end

return M
