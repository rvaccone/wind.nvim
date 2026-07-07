local api = vim.api
local fn = vim.fn

local notify = require("wind.notify")

local M = {}

---@class WindZoomState
---@field source_tab integer
---@field tab integer Lens tabpage
---@field lens integer Lens window
---@field return_win integer Window the lens currently mirrors
---@field windows integer[] Index order frozen at entry — the layout is locked
---@field showtabline integer

---@type WindZoomState|nil
local state = nil

---@return boolean
function M.active()
	return state ~= nil
end

local function sync_lens_view()
	if not state then
		return nil
	end
	local view
	if api.nvim_win_is_valid(state.lens) then
		view = api.nvim_win_call(state.lens, fn.winsaveview)
		if api.nvim_win_is_valid(state.return_win) then
			api.nvim_win_call(state.return_win, function()
				fn.winrestview(view)
			end)
		end
	end
	return view
end

local function enter()
	local engine = require("wind.engine")
	local current = api.nvim_get_current_win()
	if not engine.is_content(current) then
		notify.info("the current window is not indexed")
		return
	end

	local entering = {
		source_tab = api.nvim_get_current_tabpage(),
		return_win = current,
		windows = engine.list(),
		showtabline = vim.o.showtabline,
	}

	vim.o.showtabline = 0
	local ok, err = pcall(vim.cmd, "tab split")
	if not ok then
		vim.o.showtabline = entering.showtabline
		notify.error("could not zoom: " .. err)
		return
	end

	entering.tab = api.nvim_get_current_tabpage()
	entering.lens = api.nvim_get_current_win()
	state = entering
end

local function exit()
	local leaving = state
	if not leaving then
		return
	end
	state = nil

	vim.o.showtabline = leaving.showtabline

	local view
	if api.nvim_win_is_valid(leaving.lens) then
		view = api.nvim_win_call(leaving.lens, fn.winsaveview)
	end

	if api.nvim_tabpage_is_valid(leaving.tab) then
		pcall(function()
			api.nvim_set_current_tabpage(leaving.tab)
			vim.cmd("tabclose")
		end)
	end

	if api.nvim_tabpage_is_valid(leaving.source_tab) then
		pcall(api.nvim_set_current_tabpage, leaving.source_tab)
	end
	if api.nvim_win_is_valid(leaving.return_win) then
		api.nvim_set_current_win(leaving.return_win)
		if view then
			fn.winrestview(view)
		end
	end
end

function M.toggle()
	if state then
		exit()
	else
		enter()
	end
end

--- Point the lens at window n without leaving the zoom.
---@param n integer
function M.lens_focus(n)
	if not state then
		return
	end

	local target = state.windows[n]
	if not target or not api.nvim_win_is_valid(target) then
		notify.info(("window %d does not exist"):format(n))
		return
	end

	sync_lens_view()

	api.nvim_win_set_buf(state.lens, api.nvim_win_get_buf(target))
	local view = api.nvim_win_call(target, fn.winsaveview)
	api.nvim_win_call(state.lens, function()
		fn.winrestview(view)
	end)
	state.return_win = target
end

--- Recover cleanly if the lens tab is closed behind our back.
function M.setup()
	api.nvim_create_autocmd("TabClosed", {
		group = api.nvim_create_augroup("WindZoom", { clear = true }),
		callback = function()
			if state and not api.nvim_tabpage_is_valid(state.tab) then
				local orphaned = state
				state = nil
				vim.o.showtabline = orphaned.showtabline
				if api.nvim_win_is_valid(orphaned.return_win) then
					pcall(api.nvim_set_current_win, orphaned.return_win)
				end
			end
		end,
	})
end

return M
