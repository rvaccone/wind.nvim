local M = {}

local subcommands = {
	reveal = function()
		require("wind.actions").reveal()
	end,
	breaths = function()
		local breath = require("wind.breath")
		local entries = breath.entries()
		if #entries == 0 then
			vim.notify("no breaths held", vim.log.levels.INFO, { title = "wind" })
			return
		end
		require("wind.reveal").show_breaths()
	end,
	history = function()
		local actions = require("wind.actions")
		local entries = actions.history()
		local pointer = actions.history_pointer()
		local chunks = {}
		local first = math.max(1, #entries - 9)
		for i = first, #entries do
			local marker = i == pointer and "› " or "  "
			chunks[#chunks + 1] = { ("%s%d %s\n"):format(marker, i, entries[i].type) }
		end
		if #chunks == 0 then
			chunks[1] = { "no layout actions yet\n" }
		end
		vim.api.nvim_echo(chunks, false, {})
	end,
	release = function(n)
		local index = tonumber(n)
		if not index then
			require("wind.notify").warn("usage: :Wind release <n>")
			return
		end
		require("wind.breath").release(index)
	end,
}

---@param opts WindConfig|nil
function M.setup(opts)
	require("wind.config").setup(opts)
	require("wind.keymaps").setup()
	require("wind.reveal").setup()
	require("wind.zoom").setup()
	require("wind.breath").setup()

	vim.api.nvim_create_user_command("Wind", function(command)
		local name = command.fargs[1] or "reveal"
		local subcommand = subcommands[name]
		if subcommand then
			subcommand(command.fargs[2])
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
M.undo = function(count)
	require("wind.actions").undo(count)
end
M.redo = function(count)
	require("wind.actions").redo(count)
end
M.equalize = function()
	require("wind.actions").equalize()
end

--- Breaths.
M.hold = function()
	require("wind.breath").hold()
end
M.update = function()
	require("wind.breath").update()
end
M.return_to = function(n)
	require("wind.breath").return_to(n)
end
M.release = function(n)
	require("wind.breath").release(n)
end
M.alternate = function()
	require("wind.breath").toggle_alternate()
end

--- Ordered content windows — usable from statuslines and scripts.
M.list = function()
	return require("wind.engine").list()
end
M.index_of = function(win)
	return require("wind.engine").index_of(win)
end

return M
