local api = vim.api
local uv = vim.uv or vim.loop

local config = require("wind.config")

local M = {}

local REST_BLEND = 15
local FADE_IN_MS = 140
local DISSOLVE_MS = 300
local STAGGER_MS = 15
local LINGER_MS = 1500
local TICK_MS = 16

---@class WindBadge
---@field win integer Float window
---@field opened_at number
---@field blend number

---@type WindBadge[]
local badges = {}
local generation = 0
local timers = {}

local function timer(delay, interval, fn)
	local handle = assert(uv.new_timer())
	timers[handle] = true
	handle:start(delay, interval or 0, vim.schedule_wrap(fn))
	return handle
end

local function stop_timer(handle)
	if handle and not handle:is_closing() then
		handle:stop()
		handle:close()
	end
	timers[handle] = nil
end

local function stop_all_timers()
	for handle in pairs(timers) do
		stop_timer(handle)
	end
end

local function ensure_highlights()
	local function attrs(name)
		local ok, hl = pcall(api.nvim_get_hl, 0, { name = name, link = false })
		return ok and hl or {}
	end
	local normal, float, comment = attrs("Normal"), attrs("NormalFloat"), attrs("Comment")

	api.nvim_set_hl(0, "WindRevealBadge", {
		fg = normal.fg,
		bg = float.bg or normal.bg,
		bold = true,
		default = true,
	})
	api.nvim_set_hl(0, "WindRevealBorder", { link = "FloatBorder", default = true })
	api.nvim_set_hl(0, "WindRevealCurrent", {
		fg = comment.fg,
		bg = float.bg or normal.bg,
		default = true,
	})
end

---@return boolean
function M.visible()
	return #badges > 0
end

--- Close every badge immediately. Interaction is never made to wait.
function M.hide()
	generation = generation + 1
	stop_all_timers()
	for _, badge in ipairs(badges) do
		if api.nvim_win_is_valid(badge.win) then
			pcall(api.nvim_win_close, badge.win, true)
		end
	end
	badges = {}
	vim.cmd("redraw")
end

local function set_blend(badge, blend)
	badge.blend = blend
	if api.nvim_win_is_valid(badge.win) then
		pcall(api.nvim_set_option_value, "winblend", math.floor(blend), { win = badge.win })
	end
end

local function ease_out(t)
	return 1 - (1 - t) * (1 - t)
end

--- Animate open badges toward their resting translucency.
---@param gen integer
local function animate_in(gen)
	local handle
	handle = timer(TICK_MS, TICK_MS, function()
		if gen ~= generation then
			return
		end
		local settled = #badges > 0
		local now = uv.now()
		for _, badge in ipairs(badges) do
			local t = math.min(1, (now - badge.opened_at) / FADE_IN_MS)
			set_blend(badge, 100 - (100 - REST_BLEND) * ease_out(t))
			settled = settled and t >= 1
		end
		-- Badges must paint even while a dispatch loop is blocked in getchar.
		vim.cmd("redraw")
		if settled then
			stop_timer(handle)
		end
	end)
end

--- Let the badges dissipate — the vapor exit, used only when idle.
---@param gen integer
local function dissolve(gen)
	local started = uv.now()
	timer(TICK_MS, TICK_MS, function()
		if gen ~= generation then
			return
		end
		local t = math.min(1, (uv.now() - started) / DISSOLVE_MS)
		for _, badge in ipairs(badges) do
			set_blend(badge, badge.blend + (100 - badge.blend) * t)
		end
		vim.cmd("redraw")
		if t >= 1 then
			M.hide()
		end
	end)
end

---@param target integer Window to badge
---@param index integer
---@param current boolean
---@param animate boolean
local function open_badge(target, index, current, animate)
	if not api.nvim_win_is_valid(target) then
		return
	end

	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	api.nvim_buf_set_lines(buf, 0, -1, false, { " " .. index .. " " })

	local width = api.nvim_win_get_width(target)
	local height = api.nvim_win_get_height(target)
	local win = api.nvim_open_win(buf, false, {
		relative = "win",
		win = target,
		row = math.max(0, math.floor(height / 2) - 1),
		col = math.max(0, math.floor((width - 5) / 2)),
		width = 3,
		height = 1,
		style = "minimal",
		border = "rounded",
		focusable = false,
		noautocmd = true,
		zindex = 60,
	})

	local body = current and "WindRevealCurrent" or "WindRevealBadge"
	local border = current and "WindRevealCurrent" or "WindRevealBorder"
	api.nvim_set_option_value("winhighlight", ("Normal:%s,FloatBorder:%s"):format(body, border), { win = win })

	local badge = { win = win, opened_at = uv.now(), blend = animate and 100 or REST_BLEND }
	set_blend(badge, badge.blend)
	badges[#badges + 1] = badge
end

---@param opts? { manual?: boolean }
function M.show(opts)
	opts = opts or {}
	local reveal_config = config.get().reveal
	if not reveal_config.enabled or require("wind.zoom").active() then
		return
	end

	M.hide()
	local gen = generation

	local engine = require("wind.engine")
	local windows = engine.list()
	if #windows == 0 then
		return
	end

	local animate = reveal_config.animate
	local current = api.nvim_get_current_win()

	for index, target in ipairs(windows) do
		if animate then
			-- The gust: badges bloom in flow order, sweeping across the layout.
			timer((index - 1) * STAGGER_MS, 0, function()
				if gen == generation then
					open_badge(target, index, target == current, true)
				end
			end)
		else
			open_badge(target, index, target == current, false)
		end
	end

	if animate then
		animate_in(gen)
	else
		vim.cmd("redraw")
	end

	if opts.manual then
		timer(LINGER_MS, 0, function()
			if gen == generation then
				if animate then
					dissolve(gen)
				else
					M.hide()
				end
			end
		end)
	end
end

--- Every window of the breath, in index order — the list is a preview of
--- what each digit will address after returning.
---@param node WindSnapshotNode
---@return string
local function breath_label(node)
	local names = {}
	local function walk(n)
		if n[1] == "leaf" then
			local tail = vim.fn.fnamemodify(n[2].path, ":t")
			names[#names + 1] = tail ~= "" and tail or "[empty]"
			return
		end
		for _, child in ipairs(n[2]) do
			walk(child)
		end
	end
	walk(node)
	return table.concat(names, " · ")
end

--- One centered panel: number, marker (• last visited, ~ drifted), files.
function M.show_breaths()
	local reveal_config = config.get().reveal
	if not reveal_config.enabled then
		return
	end

	M.hide()
	local breath = require("wind.breath")
	local entries = breath.entries()

	local lines = {}
	if #entries == 0 then
		lines[1] = " no breaths held "
	else
		local last = breath.last_visited()
		local drifted = breath.drifted()
		for n, entry in ipairs(entries) do
			local marker = " "
			if n == last then
				marker = drifted and "~" or "•"
			end
			lines[n] = (" %d %s %s "):format(n, marker, breath_label(entry.snapshot))
		end
	end

	local max_width = math.max(20, vim.o.columns - 8)
	local width = 0
	for i, line in ipairs(lines) do
		if api.nvim_strwidth(line) > max_width then
			lines[i] = vim.fn.strcharpart(line, 0, max_width - 2) .. "… "
		end
		width = math.max(width, api.nvim_strwidth(lines[i]))
	end

	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local animate = reveal_config.animate
	local win = api.nvim_open_win(buf, false, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = #lines,
		style = "minimal",
		border = "rounded",
		focusable = false,
		noautocmd = true,
		zindex = 60,
	})
	api.nvim_set_option_value("winhighlight", "Normal:WindRevealBadge,FloatBorder:WindRevealBorder", { win = win })

	local badge = { win = win, opened_at = uv.now(), blend = animate and 100 or REST_BLEND }
	set_blend(badge, badge.blend)
	badges[#badges + 1] = badge

	if animate then
		animate_in(generation)
	else
		vim.cmd("redraw")
	end
end

function M.setup()
	ensure_highlights()
	api.nvim_create_autocmd("ColorScheme", {
		group = api.nvim_create_augroup("WindReveal", { clear = true }),
		callback = ensure_highlights,
	})
end

return M
