local M = {}

---@class WindFlow
---@field horizontal? "right"|"left" Side where new side-by-side windows appear
---@field vertical? "below"|"above" Side where new stacked windows appear

---@class WindExcluded
---@field filetypes? string[] Filetypes invisible to wind
---@field bufnames? string[] Lua patterns for buffer names invisible to wind

---@class WindWindowsConfig
---@field max? integer Maximum indexed windows (1-9, never above 9)
---@field flow? WindFlow
---@field excluded? WindExcluded
---@field notify? boolean Show informational notifications

---@class WindBreathsConfig
---@field max? integer Maximum held breaths (1-9, never above 9)
---@field auto_hold_first? boolean Hold breath 1 from the initial layout

---@class WindRevealConfig
---@field enabled? boolean
---@field animate? boolean Gust stagger and vapor fades

---@class WindWindowKeys
---@field namespace? string Move digits and window verbs live here
---@field stacked? string|false Focus/create with a stacked split
---@field swap? string|false
---@field close? string|false
---@field save_close? string|false
---@field only? string|false
---@field zoom? string|false
---@field undo? string|false
---@field redo? string|false
---@field equalize? string|false
---@field grow? string|false
---@field shrink? string|false

---@class WindBreathKeys
---@field namespace? string Return digits and breath verbs live here
---@field update? string|false
---@field hold? string|false
---@field release? string|false
---@field alternate? string|false

---@class WindKeymaps
---@field prefix? string Root prefix; digits on it focus windows
---@field window? WindWindowKeys
---@field breath? WindBreathKeys

---@class WindConfig
---@field windows? WindWindowsConfig
---@field breaths? WindBreathsConfig
---@field reveal? WindRevealConfig
---@field keymaps? WindKeymaps|false

---@class WindResolvedWindowKeys
---@field namespace string
---@field stacked string|false
---@field swap string|false
---@field close string|false
---@field save_close string|false
---@field only string|false
---@field zoom string|false
---@field undo string|false
---@field redo string|false
---@field equalize string|false
---@field grow string|false
---@field shrink string|false

---@class WindResolvedBreathKeys
---@field namespace string
---@field update string|false
---@field hold string|false
---@field release string|false
---@field alternate string|false

---@class WindResolvedKeymaps
---@field prefix string
---@field window WindResolvedWindowKeys
---@field breath WindResolvedBreathKeys

---@class WindResolvedConfig
---@field windows { max: integer, flow: { horizontal: "right"|"left", vertical: "below"|"above" }, excluded: { filetypes: string[], bufnames: string[] }, notify: boolean }
---@field breaths { max: integer, auto_hold_first: boolean }
---@field reveal { enabled: boolean, animate: boolean }
---@field keymaps WindResolvedKeymaps|false

---@type WindResolvedConfig
M.defaults = {
	windows = {
		max = 9,
		flow = { horizontal = "right", vertical = "below" },
		excluded = {
			filetypes = { "help", "neo-tree", "notify" },
			bufnames = {},
		},
		notify = true,
	},
	breaths = {
		max = 9,
		auto_hold_first = true,
	},
	reveal = {
		enabled = true,
		animate = true,
	},
	keymaps = {
		prefix = "<leader>",
		window = {
			namespace = "w",
			stacked = "v",
			swap = "x",
			close = "q",
			save_close = "z",
			only = "o",
			zoom = "m",
			undo = "u",
			redo = "r",
			equalize = "=",
			grow = "+",
			shrink = "-",
		},
		breath = {
			namespace = "b",
			update = "b",
			hold = "n",
			release = "d",
			alternate = "`",
		},
	},
}

---@type WindResolvedConfig|nil
M._config = nil

local function fail(msg)
	error("wind.nvim: " .. msg, 0)
end

local function check_keys(section, tbl, allowed)
	for key in pairs(tbl) do
		if allowed[key] == nil then
			fail(("unknown option `%s.%s`"):format(section, key))
		end
	end
end

local function check_type(name, value, expected)
	if type(value) ~= expected then
		fail(("`%s` must be a %s, got %s"):format(name, expected, type(value)))
	end
end

local function check_enum(name, value, options)
	for _, option in ipairs(options) do
		if value == option then
			return
		end
	end
	fail(("`%s` must be one of: %s"):format(name, table.concat(options, ", ")))
end

local function check_max(name, value)
	if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > 9 then
		fail(("`%s` must be an integer between 1 and 9 — nine is the ceiling"):format(name))
	end
end

local function check_string_list(name, value)
	check_type(name, value, "table")
	for i, item in ipairs(value) do
		check_type(("%s[%d]"):format(name, i), item, "string")
	end
end

-- Keymap characters stay single-key so navigation, the reveal watcher, and
-- every digit family derive from the same prefixes and cannot drift apart.
local function check_key_char(name, value, optional)
	if optional and value == false then
		return
	end
	if type(value) ~= "string" or #value ~= 1 or value:match("%d") then
		fail(("`%s` must be a single non-digit character%s"):format(name, optional and " or false" or ""))
	end
end

local function check_distinct(section, tbl, fields)
	local seen = {}
	for _, field in ipairs(fields) do
		local value = tbl[field]
		if type(value) == "string" then
			if seen[value] then
				fail(
					("`%s.%s` and `%s.%s` are both %q — keymap characters must be distinct"):format(
						section,
						seen[value],
						section,
						field,
						value
					)
				)
			end
			seen[value] = field
		end
	end
end

---@param config WindResolvedConfig
local function validate(config)
	check_keys("", config, { windows = true, breaths = true, reveal = true, keymaps = true })

	local windows = config.windows
	check_keys("windows", windows, { max = true, flow = true, excluded = true, notify = true })
	check_max("windows.max", windows.max)
	check_type("windows.notify", windows.notify, "boolean")
	check_keys("windows.flow", windows.flow, { horizontal = true, vertical = true })
	check_enum("windows.flow.horizontal", windows.flow.horizontal, { "right", "left" })
	check_enum("windows.flow.vertical", windows.flow.vertical, { "below", "above" })
	check_keys("windows.excluded", windows.excluded, { filetypes = true, bufnames = true })
	check_string_list("windows.excluded.filetypes", windows.excluded.filetypes)
	check_string_list("windows.excluded.bufnames", windows.excluded.bufnames)

	local breaths = config.breaths
	check_keys("breaths", breaths, { max = true, auto_hold_first = true })
	check_max("breaths.max", breaths.max)
	check_type("breaths.auto_hold_first", breaths.auto_hold_first, "boolean")

	local reveal = config.reveal
	check_keys("reveal", reveal, { enabled = true, animate = true })
	check_type("reveal.enabled", reveal.enabled, "boolean")
	check_type("reveal.animate", reveal.animate, "boolean")

	local keymaps = config.keymaps
	if keymaps == false then
		return
	end
	check_keys("keymaps", keymaps, { prefix = true, window = true, breath = true })
	check_type("keymaps.prefix", keymaps.prefix, "string")
	if #keymaps.prefix == 0 then
		fail("`keymaps.prefix` must not be empty")
	end

	local window = keymaps.window
	local window_fields = {
		"namespace",
		"stacked",
		"swap",
		"close",
		"save_close",
		"only",
		"zoom",
		"undo",
		"redo",
		"equalize",
		"grow",
		"shrink",
	}
	check_keys("keymaps.window", window, {
		namespace = true,
		stacked = true,
		swap = true,
		close = true,
		save_close = true,
		only = true,
		zoom = true,
		undo = true,
		redo = true,
		equalize = true,
		grow = true,
		shrink = true,
	})
	check_key_char("keymaps.window.namespace", window.namespace, false)
	for _, field in ipairs(window_fields) do
		if field ~= "namespace" then
			check_key_char("keymaps.window." .. field, window[field], true)
		end
	end

	local breath = keymaps.breath
	check_keys(
		"keymaps.breath",
		breath,
		{ namespace = true, update = true, hold = true, release = true, alternate = true }
	)
	check_key_char("keymaps.breath.namespace", breath.namespace, false)
	for _, field in ipairs({ "update", "hold", "release", "alternate" }) do
		check_key_char("keymaps.breath." .. field, breath[field], true)
	end

	-- Families that live directly on the root prefix must not collide.
	check_distinct("keymaps", {
		["window.namespace"] = window.namespace,
		["window.stacked"] = window.stacked,
		["window.swap"] = window.swap,
		["window.close"] = window.close,
		["window.save_close"] = window.save_close,
		["breath.namespace"] = breath.namespace,
	}, { "window.namespace", "window.stacked", "window.swap", "window.close", "window.save_close", "breath.namespace" })
	check_distinct("keymaps.window", window, { "only", "zoom", "undo", "redo", "equalize", "grow", "shrink" })
	check_distinct("keymaps.breath", breath, { "update", "hold", "release", "alternate" })
end

---@param opts WindConfig|nil
function M.setup(opts)
	local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
	if opts and opts.keymaps == false then
		config.keymaps = false
	end
	validate(config)
	M._config = config
end

---@return WindResolvedConfig
function M.get()
	return M._config or M.defaults
end

return M
