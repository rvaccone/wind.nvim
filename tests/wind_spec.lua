local api = vim.api

vim.o.hidden = true
vim.o.updatecount = 0
vim.g.wind_test_clipboard = ""
vim.g.clipboard = {
	name = "wind-test",
	copy = {
		["+"] = function(lines)
			vim.g.wind_test_clipboard = table.concat(lines, "\n")
		end,
		["*"] = function(lines)
			vim.g.wind_test_clipboard = table.concat(lines, "\n")
		end,
	},
	paste = {
		["+"] = function()
			return vim.split(vim.g.wind_test_clipboard or "", "\n"), "v"
		end,
		["*"] = function()
			return vim.split(vim.g.wind_test_clipboard or "", "\n"), "v"
		end,
	},
}

local tests = {}

local function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

local function assert_eq(expected, actual, message)
	if expected ~= actual then
		error(
			string.format(
				"%s\nexpected: %s\nactual: %s",
				message or "assertion failed",
				vim.inspect(expected),
				vim.inspect(actual)
			)
		)
	end
end

local function assert_true(value, message)
	if not value then
		error(message or "expected value to be truthy")
	end
end

local function reset(opts)
	vim.cmd("silent! tabonly!")
	vim.cmd("silent! only!")

	for _, win in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_is_valid(win) and api.nvim_win_get_config(win).relative ~= "" then
			pcall(api.nvim_win_close, win, true)
		end
	end

	vim.cmd("enew!")
	vim.bo.filetype = ""
	vim.bo.modified = false
	vim.bo.swapfile = false
	vim.o.showtabline = 1
	vim.g.wind_test_clipboard = ""

	local wind_windows = require("wind.windows")
	wind_windows._maximize_state = nil

	local base_opts = {
		windows = { notify = false },
		clipboard = { notify = false },
	}

	require("wind").setup(vim.tbl_deep_extend("force", base_opts, opts or {}))
end

test("content windows are scoped to the current tab", function()
	reset()

	local windows = require("wind.windows")
	local first_tab = api.nvim_get_current_tabpage()

	vim.cmd("vsplit")
	assert_eq(2, #windows.list_content_windows(), "current tab should include both regular splits")

	vim.cmd("tabnew")
	local second_tab = api.nvim_get_current_tabpage()

	assert_eq(1, #windows.list_content_windows(), "new tab should not include windows from the previous tab")

	windows.focus_or_create_window(1, "vsplit")

	assert_eq(second_tab, api.nvim_get_current_tabpage(), "focus by index should not jump to another tab")
	assert_true(first_tab ~= api.nvim_get_current_tabpage(), "test should still be on the second tab")
end)

test("content windows exclude floating windows", function()
	reset()

	local float_buf = api.nvim_create_buf(false, true)
	api.nvim_open_win(float_buf, false, {
		relative = "editor",
		row = 1,
		col = 1,
		width = 10,
		height = 2,
		style = "minimal",
	})

	assert_eq(1, #require("wind.windows").list_content_windows(), "floating window should not be indexed")
end)

test("excluded filetypes and bufnames are skipped when indexing", function()
	reset({ windows = { excluded_bufnames = { "opencode" } } })

	local windows = require("wind.windows")

	windows.create_window("vsplit")
	vim.bo.filetype = "help"

	windows.create_window("vsplit")
	api.nvim_buf_set_name(0, "term://wind-opencode-test")

	assert_eq(1, #windows.list_content_windows(), "only the non-excluded window should be indexed")

	windows.focus_or_create_window(2, "vsplit")

	assert_eq(2, #windows.list_content_windows(), "focus/create should create after the last indexed window")
end)

test("directional focus/create skips excluded neighboring windows", function()
	reset()

	local windows = require("wind.windows")
	local source_win = api.nvim_get_current_win()

	windows.create_window_before_current("vsplit")
	local excluded_win = api.nvim_get_current_win()
	vim.bo.filetype = "help"

	api.nvim_set_current_win(source_win)
	windows.focus_or_create_window_after_current("vsplit")

	assert_eq(2, #windows.list_content_windows(), "a new indexed window should be created past the excluded neighbor")
	assert_true(api.nvim_get_current_win() ~= excluded_win, "excluded neighbor should not be focused")
	assert_eq("", vim.bo.filetype, "newly created window should be a normal content window")
end)

test("max_windows still prevents creating extra indexed windows", function()
	reset({ windows = { max_windows = 1 } })

	local windows = require("wind.windows")
	local tab_window_count = #api.nvim_tabpage_list_wins(0)

	windows.create_window("vsplit")

	assert_eq(1, #windows.list_content_windows(), "content window count should stay capped")
	assert_eq(tab_window_count, #api.nvim_tabpage_list_wins(0), "no split should be created after hitting max_windows")
end)

test("zero based indexing still maps to current tab content windows", function()
	reset({ windows = { zero_based_indexing = true } })

	local windows = require("wind.windows")

	windows.create_window("vsplit")
	local content_windows = windows.list_content_windows()
	local first_window = content_windows[1]
	local second_window = content_windows[2]

	windows.focus_or_create_window(1, "vsplit")
	assert_eq(second_window, api.nvim_get_current_win(), "index 1 should focus the second content window")

	windows.focus_or_create_window(0, "vsplit")
	assert_eq(first_window, api.nvim_get_current_win(), "index 0 should focus the first content window")
end)

test("swap_window still swaps buffers and focuses the target window", function()
	reset()

	local windows = require("wind.windows")

	windows.create_window("vsplit")

	local content_windows = windows.list_content_windows()
	local first_window = content_windows[1]
	local second_window = content_windows[2]

	api.nvim_buf_set_lines(api.nvim_win_get_buf(first_window), 0, -1, false, { "first" })
	api.nvim_buf_set_lines(api.nvim_win_get_buf(second_window), 0, -1, false, { "second" })

	api.nvim_set_current_win(first_window)
	windows.swap_window(2)

	assert_eq(second_window, api.nvim_get_current_win(), "swap should focus the target window")
	assert_eq("second", api.nvim_buf_get_lines(api.nvim_win_get_buf(first_window), 0, 1, false)[1])
	assert_eq("first", api.nvim_buf_get_lines(api.nvim_win_get_buf(second_window), 0, 1, false)[1])
end)

test("toggle_maximize closes the maximized tab even when another tab is current", function()
	reset()

	local windows = require("wind.windows")
	local source_tab = api.nvim_get_current_tabpage()

	windows.toggle_maximize()
	local maximized_tab = api.nvim_get_current_tabpage()

	assert_true(maximized_tab ~= source_tab, "maximize should create a separate tab")

	vim.cmd("tabnew")
	local extra_tab = api.nvim_get_current_tabpage()

	assert_eq(3, vim.fn.tabpagenr("$"), "test should have source, maximized, and extra tabs")

	windows.toggle_maximize()

	assert_eq(2, vim.fn.tabpagenr("$"), "restore should close only the maximized tab")
	assert_true(not api.nvim_tabpage_is_valid(maximized_tab), "maximized tab should be closed")
	assert_true(api.nvim_tabpage_is_valid(extra_tab), "unrelated tab should remain open")
	assert_eq(source_tab, api.nvim_get_current_tabpage(), "restore should return to the source tab")
end)

test("new close with save keymap config registers dynamic keymaps", function()
	reset({
		windows = {
			max_windows = 1,
			keymaps = {
				close_window_with_save = "<Plug>(WindTestCloseSave)",
			},
		},
	})

	local mapping = vim.fn.maparg("<Plug>(WindTestCloseSave)1", "n", false, true)

	assert_eq("Close window 1 with save", mapping.desc, "renamed keymap should be registered")
end)

test("line_separator controls AI clipboard formatting", function()
	reset({ clipboard = { ai = { line_separator = "|" } } })

	api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two" })

	require("wind.clipboard").yank_current_window_ai()

	assert_eq(
		"=== FILE BEGIN ===|Path: [No Name]|Filetype: |Lines: 2|--- CONTENT ---|one|two|=== FILE END ===",
		vim.fn.getreg("+"),
		"AI clipboard output should use the configured line_separator"
	)
end)

test("deprecated config aliases are migrated", function()
	reset({
		windows = { keymaps = { close_window_and_swap = false } },
		clipboard = { ai = { separator = "|" } },
	})

	local config = require("wind.config").get()

	assert_eq(
		false,
		config.windows.keymaps.close_window_with_save,
		"old close_window_and_swap should map to the new key"
	)
	assert_eq("|", config.clipboard.ai.line_separator, "old separator should map to line_separator")
end)

local failures = {}

for _, spec in ipairs(tests) do
	local ok, err = xpcall(spec.fn, debug.traceback)

	if ok then
		print("ok - " .. spec.name)
	else
		print("not ok - " .. spec.name)
		print(err)
		table.insert(failures, spec.name)
	end
end

if #failures > 0 then
	vim.cmd("cquit")
end

vim.cmd("qa!")
