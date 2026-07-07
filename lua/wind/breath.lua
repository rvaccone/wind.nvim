local api = vim.api

local config = require("wind.config")
local notify = require("wind.notify")
local snapshot = require("wind.snapshot")

local M = {}

---@class WindBreath
---@field snapshot WindSnapshotNode

---@type WindBreath[]
local held = {}
---@type integer|nil
local last_visited = nil
---@type WindSnapshotNode|nil
local alternate = nil

---@return WindBreath[]
function M.entries()
	return held
end

---@return integer|nil
function M.last_visited()
	return last_visited
end

--- Whether the layout has changed since the last-visited breath.
---@return boolean
function M.drifted()
	local entry = last_visited and held[last_visited]
	if not entry then
		return false
	end
	return not vim.deep_equal(snapshot.normalize(snapshot.capture()), snapshot.normalize(entry.snapshot))
end

--- Jump-class operations park the layout they leave here.
function M.set_alternate()
	alternate = snapshot.capture()
end

---@param opts? { silent?: boolean }
function M.hold(opts)
	local max = config.get().breaths.max
	if #held >= max then
		notify.info(("All %d breaths are held, release one first"):format(max))
		return
	end
	local captured = snapshot.capture()
	if not captured then
		return
	end
	held[#held + 1] = { snapshot = captured }
	last_visited = #held
	if not (opts and opts.silent) then
		notify.info(("Held breath %d"):format(#held))
	end
end

function M.update()
	local entry = last_visited and held[last_visited]
	if not entry then
		notify.info("No breath to update, hold one first")
		return
	end
	local captured = snapshot.capture()
	if not captured then
		return
	end
	entry.snapshot = captured
	notify.info(("Breath %d updated"):format(last_visited))
end

--- Toggle between the current layout and the one last jumped away from.
function M.toggle_alternate()
	if not alternate then
		notify.info("No alternate layout yet")
		return
	end
	require("wind.zoom").exit()
	require("wind.actions").record_jump("alternate", function()
		local target = alternate
		alternate = snapshot.capture()
		snapshot.restore(target)
	end)
end

--- Return to breath n. When it isn't held, hold the current layout as the
--- next breath instead — declaring a destination brings it into being,
--- exactly like window creation, and holding is never destructive.
---@param n integer
function M.return_to(n)
	local entry = held[n]
	if not entry then
		M.hold()
		return
	end

	-- Returning to the breath you are already on bounces to the alternate.
	if n == last_visited and not M.drifted() then
		M.toggle_alternate()
		return
	end

	require("wind.zoom").exit()
	require("wind.actions").record_jump("return", function()
		alternate = snapshot.capture()
		snapshot.restore(entry.snapshot)
	end)
	last_visited = n
end

--- Release breath n. Numbers shift down, exactly like windows. The last
--- breath can never be released, so update and the alternate toggle always
--- have a target.
---@param n integer
function M.release(n)
	if not held[n] then
		notify.info(("Breath %d is not held"):format(n))
		return
	end
	if #held == 1 then
		notify.info("The last breath cannot be released")
		return
	end
	table.remove(held, n)
	if last_visited then
		if last_visited == n then
			last_visited = nil
		elseif last_visited > n then
			last_visited = last_visited - 1
		end
	end
	notify.info(("Released breath %d"):format(n))
end

--- Release the breath you are on. Targeted release stays on
--- `:Wind release <n>`.
function M.release_current()
	if not last_visited then
		notify.info("No breath is current")
		return
	end
	M.release(last_visited)
end

--- Test hook: forget everything.
function M.reset()
	held = {}
	last_visited = nil
	alternate = nil
end

--- Hold breath 1 from the initial layout so update and the alternate
--- toggle always have a target.
function M.setup()
	if not config.get().breaths.auto_hold_first then
		return
	end
	local function first_hold()
		if #held == 0 then
			M.hold({ silent = true })
		end
	end
	if vim.v.vim_did_enter == 1 then
		first_hold()
	else
		api.nvim_create_autocmd("VimEnter", {
			group = api.nvim_create_augroup("WindBreath", { clear = true }),
			once = true,
			callback = function()
				vim.schedule(first_hold)
			end,
		})
	end
end

return M
