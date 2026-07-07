local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop

local config = require("wind.config")

local M = {}

local FADE_IN_MS = 140
local DISSOLVE_MS = 300
local STAGGER_MS = 15
local LINGER_MS = 1500
local TICK_MS = 16
local CONTINUITY_MS = 400
local CELL_MAX_WIDTH = 22

local hl_namespace = api.nvim_create_namespace("wind.reveal.hl")

---@class WindBadge
---@field win integer Float window
---@field opened_at number
---@field blend number

---@type WindBadge[]
local badges = {}
local generation = 0
local timers = {}
local last_hidden = 0

local function timer(delay, interval, callback)
	local handle = assert(uv.new_timer())
	timers[handle] = true
	handle:start(delay, interval or 0, vim.schedule_wrap(callback))
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

--- Pure links: the overlay inherits the theme — including transparent
--- backgrounds — exactly like a which-key window. Bold is layered on via
--- extmarks so it combines with whatever the theme provides.
local function ensure_highlights()
	api.nvim_set_hl(0, "WindRevealBadge", { link = "NormalFloat", default = true })
	api.nvim_set_hl(0, "WindRevealBorder", { link = "FloatBorder", default = true })
	api.nvim_set_hl(0, "WindRevealCurrent", { link = "Comment", default = true })
	api.nvim_set_hl(0, "WindRevealBold", { bold = true, default = true })
end

---@return boolean
function M.visible()
	return #badges > 0
end

--- Guidance was on screen a moment ago — used for continuity so a family
--- trigger following a bare-prefix reveal re-shows without a fresh delay.
---@return boolean
function M.recently_visible()
	return uv.now() - last_hidden < CONTINUITY_MS
end

--- Close every badge immediately. Interaction is never made to wait.
function M.hide()
	generation = generation + 1
	stop_all_timers()
	if #badges > 0 then
		last_hidden = uv.now()
	end
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

--- Animate open badges in from vapor to fully settled.
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
			set_blend(badge, 100 * (1 - ease_out(t)))
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

---@param buf integer
---@param row integer
---@param start_col integer
---@param end_col integer
local function bold(buf, row, start_col, end_col)
	api.nvim_buf_set_extmark(buf, hl_namespace, row, start_col, {
		end_row = row,
		end_col = end_col,
		hl_group = "WindRevealBold",
	})
end

---@param float integer
---@param current? boolean
local function style_float(float, current)
	local body = current and "WindRevealCurrent" or "WindRevealBadge"
	local border = current and "WindRevealCurrent" or "WindRevealBorder"
	api.nvim_set_option_value("winhighlight", ("Normal:%s,FloatBorder:%s"):format(body, border), { win = float })
	api.nvim_set_option_value("wrap", false, { win = float })
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
	local line = " " .. index .. " "
	api.nvim_buf_set_lines(buf, 0, -1, false, { line })
	bold(buf, 0, 0, #line)

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
	style_float(win, current)

	local badge = { win = win, opened_at = uv.now(), blend = animate and 100 or 0 }
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

---@param text string
---@return string
local function clamp_cell(text)
	if api.nvim_strwidth(text) > CELL_MAX_WIDTH then
		return fn.strcharpart(text, 0, CELL_MAX_WIDTH - 1) .. "…"
	end
	return text
end

---@param node WindSnapshotNode
---@return string[]
local function breath_files(node)
	local names = {}
	local function walk(n)
		if n[1] == "leaf" then
			local tail = fn.fnamemodify(n[2].path, ":t")
			names[#names + 1] = clamp_cell(tail ~= "" and tail or "[empty]")
			return
		end
		for _, child in ipairs(n[2]) do
			walk(child)
		end
	end
	walk(node)
	return names
end

--- One panel, one column per breath: the header row is the number
--- (`•` last visited, `~` drifted), each row beneath a window's file in
--- index order — a preview of what each digit will address.
function M.show_breaths()
	local reveal_config = config.get().reveal
	if not reveal_config.enabled then
		return
	end

	M.hide()

	local breath = require("wind.breath")
	local entries = breath.entries()
	local last = breath.last_visited()
	local drifted = breath.drifted()

	local lines
	local header_spans = {}

	if #entries == 0 then
		lines = { " no breaths held " }
	else
		local columns = {}
		local rows = 0
		for n, entry in ipairs(entries) do
			local header = tostring(n)
			if n == last then
				header = header .. " " .. (drifted and "~" or "•")
			end
			local files = breath_files(entry.snapshot)
			local width = api.nvim_strwidth(header)
			for _, name in ipairs(files) do
				width = math.max(width, api.nvim_strwidth(name))
			end
			columns[n] = { header = header, files = files, width = width }
			rows = math.max(rows, #files)
		end

		local function pad(text, width)
			return text .. string.rep(" ", width - api.nvim_strwidth(text))
		end

		lines = {}
		for row = 0, rows do
			local cells = {}
			for n, column in ipairs(columns) do
				local text = row == 0 and column.header or (column.files[row] or "")
				if row == 0 then
					local before = table.concat(cells, "  ")
					local start_col = #(" " .. before) + (n > 1 and 2 or 0)
					header_spans[#header_spans + 1] = { start_col, start_col + #text }
				end
				cells[#cells + 1] = pad(text, column.width)
			end
			lines[row + 1] = (" %s "):format(table.concat(cells, "  "))
		end
	end

	local max_width = math.max(20, vim.o.columns - 8)
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, math.min(max_width, api.nvim_strwidth(line)))
	end

	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	for _, span in ipairs(header_spans) do
		bold(buf, 0, span[1], span[2])
	end

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
	style_float(win)

	local badge = { win = win, opened_at = uv.now(), blend = animate and 100 or 0 }
	set_blend(badge, badge.blend)
	badges[#badges + 1] = badge

	if animate then
		animate_in(generation)
	else
		vim.cmd("redraw")
	end
end

---@return string
local function resolved_prefix()
	local keymaps = config.get().keymaps
	if keymaps == false then
		return ""
	end
	local leader = vim.g.mapleader
	if leader == nil or leader == "" then
		leader = "\\"
	end
	local prefix = keymaps.prefix:gsub("<[Ll]eader>", leader)
	return api.nvim_replace_termcodes(prefix, true, true, true)
end

---@param mode string
---@return boolean
local function in_normal_or_visual(mode)
	return mode == "n" or mode == "v" or mode == "V" or mode == "\22"
end

--- Observe the bare prefix and reveal on hesitation. wind never maps the
--- prefix itself — that would steal it from which-key and every other
--- leader mapping. It only watches: in setups where a plugin like
--- which-key consumes the prefix immediately, badges appear right at
--- `delay_ms`; without one they appear when the pending mapping resolves.
--- Spatial badges and a which-key popup are complementary, not rivals.
local function watch_bare_prefix()
	local prefix = resolved_prefix()
	if prefix == "" then
		return
	end

	local recent = ""
	local pending = nil

	vim.on_key(function(key, typed)
		local ok = pcall(function()
			local pressed = (typed and typed ~= "") and typed or key
			if pressed == "" then
				return
			end
			recent = (recent .. pressed):sub(-16)

			if pending then
				stop_timer(pending)
				pending = nil
			end
			if M.visible() then
				M.hide()
			end

			if not in_normal_or_visual(api.nvim_get_mode().mode) then
				return
			end

			if recent:sub(-#prefix) == prefix then
				pending = timer(config.get().reveal.delay_ms, 0, function()
					pending = nil
					M.show()
				end)
			end
		end)
		if not ok then
			recent = ""
		end
	end, api.nvim_create_namespace("wind.reveal"))
end

function M.setup()
	ensure_highlights()
	api.nvim_create_autocmd("ColorScheme", {
		group = api.nvim_create_augroup("WindReveal", { clear = true }),
		callback = ensure_highlights,
	})

	if config.get().keymaps ~= false and config.get().reveal.enabled then
		watch_bare_prefix()
	end
end

return M
