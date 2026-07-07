vim.opt.runtimepath:prepend(".")
vim.o.columns = 220
vim.o.lines = 60
vim.o.swapfile = false

local api = vim.api
local fn = vim.fn

local passed, failed = 0, 0
local failures = {}

local function reset()
	pcall(vim.cmd, "silent! tabonly!")
	pcall(vim.cmd, "silent! only!")
	pcall(vim.cmd, "silent! %bwipeout!")
end

local function test(name, body)
	reset()
	local ok, err = pcall(body)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		failures[#failures + 1] = ("  ✗ %s\n    %s"):format(name, err)
	end
end

local function eq(actual, expected, label)
	if not vim.deep_equal(actual, expected) then
		error(("%s: expected %s, got %s"):format(label or "eq", vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

local function ok(condition, label)
	if not condition then
		error(label or "expected truthy", 2)
	end
end

local function edit(name)
	vim.cmd("silent edit " .. fn.fnameescape(name))
	return api.nvim_get_current_buf()
end

local function screen_col(win)
	return fn.win_screenpos(win)[2]
end

local function screen_row(win)
	return fn.win_screenpos(win)[1]
end

local function float_count()
	local count = 0
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		if api.nvim_win_get_config(win).relative ~= "" then
			count = count + 1
		end
	end
	return count
end

-- Configuration validation rejects anything that could break the model.
test("config: rejects max above nine", function()
	ok(not pcall(require("wind.config").setup, { windows = { max = 10 } }), "max = 10 must fail")
end)

test("config: rejects duplicate keymap characters", function()
	ok(not pcall(require("wind.config").setup, { keymaps = { window = { swap = "q" } } }), "swap = close must fail")
end)

test("config: rejects unknown options", function()
	ok(not pcall(require("wind.config").setup, { windows = { max_windows = 9 } }), "v0 option must fail loudly")
end)

test("config: rejects multi-character verbs", function()
	ok(not pcall(require("wind.config").setup, { keymaps = { window = { zoom = "mm" } } }), "'mm' must fail")
end)

local test_config = {
	windows = { notify = false },
	reveal = { animate = false },
}
require("wind").setup(vim.deepcopy(test_config))

local wind = require("wind")
local engine = require("wind.engine")
local actions = require("wind.actions")
local config = require("wind.config")

local function with_config(opts, body)
	config.setup(vim.tbl_deep_extend("force", vim.deepcopy(test_config), opts))
	local ok_body, err = pcall(body)
	config.setup(vim.deepcopy(test_config))
	if not ok_body then
		error(err, 2)
	end
end

test("index order follows the screen left to right", function()
	local a = edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	local b = edit("spec_b")
	wind.focus_or_create(9, "vsplit")
	local c = edit("spec_c")

	local windows = engine.list()
	eq(#windows, 3, "window count")
	eq(
		{ api.nvim_win_get_buf(windows[1]), api.nvim_win_get_buf(windows[2]), api.nvim_win_get_buf(windows[3]) },
		{ a, b, c },
		"buffer order"
	)
end)

test("excluded filetypes are invisible to the index", function()
	edit("spec_main")
	vim.cmd("leftabove vsplit")
	vim.cmd("enew")
	vim.bo.filetype = "neo-tree"

	eq(#engine.list(), 1, "content windows")
	ok(not engine.is_content(api.nvim_get_current_win()), "excluded window is not content")
end)

test("focus jumps to an existing window without creating", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")

	wind.focus_or_create(1, "vsplit")
	eq(engine.index_of(), 1, "focused window 1")
	eq(#engine.list(), 2, "no window created")
end)

test("creation anchors at the current window", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")
	wind.focus_or_create(9, "vsplit")
	edit("spec_c")

	wind.focus_or_create(2, "vsplit")
	local middle = api.nvim_get_current_win()
	wind.focus_or_create(9, "split")

	local created = api.nvim_get_current_win()
	eq(#engine.list(), 4, "one window created")
	eq(screen_col(created), screen_col(middle), "created below the middle column")
	ok(screen_row(created) > screen_row(middle), "created below, not above")
	eq(engine.index_of(created), 4, "geometric index of the new window")
end)

test("creation ignores splitright and splitbelow", function()
	for _, splitright in ipairs({ false, true }) do
		reset()
		vim.o.splitright = splitright
		vim.o.splitbelow = splitright
		local origin = api.nvim_get_current_win()
		edit("spec_origin_" .. tostring(splitright))

		wind.focus_or_create(9, "vsplit")
		local created = api.nvim_get_current_win()
		ok(screen_col(created) > screen_col(origin), "flow right regardless of splitright")

		wind.focus_or_create(1, "vsplit")
		wind.focus_or_create(9, "split")
		ok(screen_row(api.nvim_get_current_win()) > screen_row(origin), "flow below regardless of splitbelow")
	end
	vim.o.splitright = false
	vim.o.splitbelow = false
end)

test("flow left reverses creation side and index order", function()
	with_config({ windows = { flow = { horizontal = "left" } } }, function()
		local origin = api.nvim_get_current_win()
		edit("spec_rtl")
		wind.focus_or_create(9, "vsplit")
		local created = api.nvim_get_current_win()

		ok(screen_col(created) < screen_col(origin), "created to the left")
		eq(engine.index_of(origin), 1, "rightmost window is index 1")
		eq(engine.index_of(created), 2, "new window takes the next index")
	end)
end)

test("max windows is enforced", function()
	with_config({ windows = { max = 2 } }, function()
		edit("spec_a")
		wind.focus_or_create(9, "vsplit")
		edit("spec_b")
		wind.focus_or_create(9, "vsplit")
		eq(#engine.list(), 2, "creation refused at the ceiling")
	end)
end)

test("close targets by index and preserves focus", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")
	wind.focus_or_create(9, "vsplit")
	local c = edit("spec_c")

	wind.close(1)
	eq(#engine.list(), 2, "window closed")
	eq(api.nvim_get_current_buf(), c, "focus stayed where it was")
end)

test("closing the last window never quits", function()
	edit("spec_only")
	wind.close(1)
	eq(#engine.list(), 1, "last window survives")
end)

test("save_close writes before closing", function()
	local path = fn.tempname()
	edit("spec_keep")
	wind.focus_or_create(9, "vsplit")
	edit(path)
	api.nvim_buf_set_lines(0, 0, -1, false, { "held breath" })

	wind.save_close(2)
	eq(#engine.list(), 1, "window closed")
	eq(fn.readfile(path), { "held breath" }, "buffer was written")
	fn.delete(path)
end)

test("move shifts everything between", function()
	local a = edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	local b = edit("spec_b")
	wind.focus_or_create(9, "vsplit")
	local c = edit("spec_c")

	wind.move(1)
	local windows = engine.list()
	eq(
		{ api.nvim_win_get_buf(windows[1]), api.nvim_win_get_buf(windows[2]), api.nvim_win_get_buf(windows[3]) },
		{ c, a, b },
		"third window moved to first, others shifted"
	)
	eq(engine.index_of(), 1, "focus travels with the moved window")
end)

test("swap exchanges exactly two windows", function()
	local a = edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	local b = edit("spec_b")
	wind.focus_or_create(9, "vsplit")
	local c = edit("spec_c")

	wind.focus_or_create(1, "vsplit")
	wind.swap(3)
	local windows = engine.list()
	eq(
		{ api.nvim_win_get_buf(windows[1]), api.nvim_win_get_buf(windows[2]), api.nvim_win_get_buf(windows[3]) },
		{ c, b, a },
		"first and third exchanged"
	)
	eq(engine.index_of(), 3, "focus follows the moved content")
end)

test("only clears content windows and spares excluded ones", function()
	edit("spec_a")
	vim.cmd("leftabove vsplit")
	vim.cmd("enew")
	vim.bo.filetype = "neo-tree"
	local tree = api.nvim_get_current_win()

	wind.focus_or_create(1, "vsplit")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")
	wind.focus_or_create(9, "vsplit")
	edit("spec_c")

	wind.only()
	eq(#engine.list(), 1, "one content window remains")
	ok(api.nvim_win_is_valid(tree), "excluded window untouched")
end)

test("zoom is a lens: navigation moves it, structure is locked", function()
	local a = edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	local b = edit("spec_b")
	wind.focus_or_create(1, "vsplit")

	wind.zoom()
	eq(#api.nvim_list_tabpages(), 2, "lens tabpage opened")
	eq(api.nvim_get_current_buf(), a, "lens shows the zoomed window")

	wind.focus_or_create(2, "vsplit")
	eq(api.nvim_get_current_buf(), b, "lens followed to window 2")
	eq(#api.nvim_list_tabpages(), 2, "still zoomed")

	wind.move(1)
	wind.close(1)
	wind.only()
	eq(#api.nvim_list_tabpages(), 2, "structural operations blocked")

	wind.zoom()
	eq(#api.nvim_list_tabpages(), 1, "lens closed")
	eq(api.nvim_get_current_buf(), b, "returned to the window the lens was on")
	eq(#engine.list(), 2, "layout untouched")
	eq(vim.o.showtabline, 1, "showtabline restored")
end)

test("every mutation lands in the history", function()
	local history = actions.history()
	local base = #history

	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	wind.close(2)

	eq(#history - base, 2, "create and close recorded")
	eq(history[#history].type, "close", "latest action type")
	eq(history[#history - 1].type, "create", "prior action type")
end)

test("snapshot captures a content-only tree", function()
	edit("spec_a")
	vim.cmd("leftabove vsplit")
	vim.cmd("enew")
	vim.bo.filetype = "neo-tree"
	wind.focus_or_create(1, "vsplit")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")

	local shot = require("wind.snapshot").capture() --[[@as any]]
	ok(shot ~= nil, "snapshot exists")
	eq(shot[1], "row", "root is a row")
	eq(#shot[2], 2, "two content leaves, excluded window pruned")
	eq(shot[2][1][1], "leaf", "leaf shape")
	ok(shot[2][1][2].path:find("spec_a", 1, true) ~= nil, "leaf records its path")
end)

test("reveal badges one float per window and dismisses instantly", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")

	local reveal = require("wind.reveal")
	reveal.show()
	eq(float_count(), 2, "one badge per content window")
	ok(reveal.visible(), "reveal reports visible")

	reveal.hide()
	eq(float_count(), 0, "badges close instantly")
end)

local snapshot = require("wind.snapshot")
local breath = require("wind.breath")

local function release_all()
	while #breath.entries() > 0 do
		breath.release(1)
	end
end

local function tempfile(lines)
	local path = fn.resolve(fn.tempname())
	fn.writefile(lines, path)
	return path
end

test("breath 1 is auto-held when the session enters", function()
	release_all()
	edit("spec_first")
	-- -c scripts run before VimEnter, so fire it explicitly.
	api.nvim_exec_autocmds("VimEnter", {})
	vim.wait(500, function()
		return #breath.entries() == 1
	end, 10)
	eq(#breath.entries(), 1, "initial layout held as breath 1")
	release_all()
end)

test("snapshot restore rebuilds structure, paths, cursors, and focus", function()
	local path_a = tempfile({ "a1", "a2", "a3", "a4", "a5" })
	local path_b = tempfile({ "b1", "b2", "b3" })
	local path_c = tempfile({ "c1", "c2" })

	edit(path_a)
	api.nvim_win_set_cursor(0, { 5, 0 })
	wind.focus_or_create(9, "vsplit")
	edit(path_b)
	api.nvim_win_set_cursor(0, { 3, 0 })
	wind.focus_or_create(9, "split")
	edit(path_c)
	api.nvim_win_set_cursor(0, { 2, 0 })

	local shot = snapshot.capture()
	wind.only()
	vim.cmd("silent enew")
	eq(#engine.list(), 1, "layout mangled")

	ok(snapshot.restore(shot), "restore succeeded")
	local windows = engine.list()
	eq(#windows, 3, "three windows rebuilt")

	local names = {}
	for i, win in ipairs(windows) do
		names[i] = api.nvim_buf_get_name(api.nvim_win_get_buf(win))
	end
	eq(names, { path_a, path_b, path_c }, "paths in flow order")

	eq(api.nvim_win_call(windows[1], fn.winsaveview).lnum, 5, "cursor restored in window 1")
	eq(api.nvim_win_call(windows[2], fn.winsaveview).lnum, 3, "cursor restored in window 2")
	eq(api.nvim_get_current_win(), windows[3], "focus returned to the captured window")

	for _, path in ipairs({ path_a, path_b, path_c }) do
		fn.delete(path)
	end
end)

test("restore rebuilds around excluded windows", function()
	edit("spec_a")
	vim.cmd("leftabove vsplit")
	vim.cmd("enew")
	vim.bo.filetype = "neo-tree"
	local tree = api.nvim_get_current_win()

	wind.focus_or_create(1, "vsplit")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")

	local shot = snapshot.capture()
	wind.only()
	ok(snapshot.restore(shot), "restore succeeded")

	eq(#engine.list(), 2, "content windows rebuilt")
	ok(api.nvim_win_is_valid(tree), "excluded window survived the restore")
end)

test("undo walks back and redo walks forward", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	edit("spec_b")
	eq(#engine.list(), 2, "created")

	wind.undo()
	eq(#engine.list(), 1, "create undone")

	wind.redo()
	eq(#engine.list(), 2, "create redone")
end)

test("undo restores a closed window with its file", function()
	local path = tempfile({ "kept" })
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	edit(path)

	wind.close(2)
	eq(#engine.list(), 1, "closed")

	wind.undo()
	local windows = engine.list()
	eq(#windows, 2, "window restored")
	eq(api.nvim_buf_get_name(api.nvim_win_get_buf(windows[2])), path, "same file back at index 2")
	fn.delete(path)
end)

test("undo is count-aware", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	wind.focus_or_create(9, "vsplit")
	eq(#engine.list(), 3, "two creates")

	wind.undo(2)
	eq(#engine.list(), 1, "both undone in one call")
end)

test("undo never touches buffer contents", function()
	edit("spec_dirty")
	api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved work" })
	local dirty = api.nvim_get_current_buf()

	wind.focus_or_create(9, "vsplit")
	wind.undo()

	eq(#engine.list(), 1, "layout undone")
	eq(api.nvim_buf_get_lines(dirty, 0, -1, false), { "unsaved work" }, "modified buffer untouched")
	eq(vim.bo[dirty].modified, true, "still marked modified")
end)

test("move is undoable", function()
	local a = edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	local b = edit("spec_b")

	wind.move(1)
	local moved = engine.list()
	eq(api.nvim_win_get_buf(moved[1]), b, "moved")

	wind.undo()
	local windows = engine.list()
	eq(
		{ vim.fn.bufname(api.nvim_win_get_buf(windows[1])), vim.fn.bufname(api.nvim_win_get_buf(windows[2])) },
		{ vim.fn.bufname(a), vim.fn.bufname(b) },
		"original order restored"
	)
end)

test("breaths: hold, drift, update, return, alternate, shifting release", function()
	release_all()
	local path_a = tempfile({ "a" })
	local path_b = tempfile({ "b" })

	edit(path_a)
	breath.hold()
	eq(#breath.entries(), 1, "breath 1 held")
	eq(breath.drifted(), false, "no drift yet")

	wind.focus_or_create(9, "vsplit")
	edit(path_b)
	eq(breath.drifted(), true, "layout drifted from breath 1")

	breath.hold()
	eq(#breath.entries(), 2, "breath 2 held")
	eq(breath.drifted(), false, "holding pins the current layout")

	breath.return_to(1)
	eq(#engine.list(), 1, "returned to the single-window breath")
	eq(breath.last_visited(), 1, "last visited tracks the return")

	breath.return_to(2)
	eq(#engine.list(), 2, "returned to the two-window breath")

	breath.toggle_alternate()
	eq(#engine.list(), 1, "alternate bounces to the layout left behind")
	breath.toggle_alternate()
	eq(#engine.list(), 2, "and back")

	breath.release(1)
	eq(#breath.entries(), 1, "released")
	eq(breath.last_visited(), 1, "numbers shifted — old breath 2 is now breath 1")
	eq(breath.drifted(), false, "current layout matches the shifted breath")

	release_all()
	fn.delete(path_a)
	fn.delete(path_b)
end)

test("resize: smart dimension steps and equalize", function()
	edit("spec_a")
	wind.focus_or_create(9, "vsplit")
	wind.focus_or_create(9, "vsplit")
	wind.focus_or_create(2, "vsplit")

	local before = api.nvim_win_get_width(0)
	engine.resize_step("grow")
	eq(api.nvim_win_get_width(0), before + 3, "grow widens by one step")
	engine.resize_step("shrink")
	eq(api.nvim_win_get_width(0), before, "shrink reverses it")

	engine.resize_step("grow")
	wind.equalize()
	local widths = {}
	for i, win in ipairs(engine.list()) do
		widths[i] = api.nvim_win_get_width(win)
	end
	ok(math.abs(widths[1] - widths[2]) <= 1 and math.abs(widths[2] - widths[3]) <= 1, "equalized")
end)

test("breath cards render, list every window, and dismiss", function()
	release_all()
	edit("spec_alpha")
	wind.focus_or_create(9, "vsplit")
	edit("spec_beta")
	breath.hold()

	local reveal = require("wind.reveal")
	reveal.show_breaths()
	eq(float_count(), 1, "one card panel")

	local card_line
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		if api.nvim_win_get_config(win).relative ~= "" then
			card_line = api.nvim_buf_get_lines(api.nvim_win_get_buf(win), 0, 1, false)[1]
		end
	end
	ok(card_line:find("spec_alpha", 1, true) ~= nil, "first window listed")
	ok(card_line:find("spec_beta", 1, true) ~= nil, "second window listed")
	ok(card_line:find("spec_alpha", 1, true) < card_line:find("spec_beta", 1, true), "listed in index order")

	reveal.hide()
	eq(float_count(), 0, "dismissed")
	release_all()
end)

print(("\nwind: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	print(table.concat(failures, "\n"))
	vim.cmd("cquit!")
else
	vim.cmd("quitall!")
end
