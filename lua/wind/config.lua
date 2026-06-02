-- Localized vim variables
local deepcopy = vim.deepcopy
local tbl_deep_extend = vim.tbl_deep_extend

local M = {}

---@class WindWindowsConfig
---@field excluded_bufnames string[] Lua patterns to match buffer names that should be excluded from window indexing
---@field excluded_filetypes string[] Filetypes to exclude from window indexing
---@field max_windows integer Maximum number of windows to index
---@field zero_based_indexing boolean Use 0-based indexing instead of 1-based
---@field notify boolean Show notifications for window operations
---@field keymaps? WindWindowsKeymaps|false Window keymaps configuration

---@class WindWindowsKeymaps
---@field focus_or_create_horizontal_window? string|false Keymap prefix for horizontal windows
---@field focus_or_create_vertical_window? string|false Keymap prefix for vertical windows
---@field swap_window? string|false Keymap prefix for swapping windows
---@field close_window? string|false Keymap prefix for closing windows
---@field close_window_with_save? string|false Keymap prefix for closing windows with save
---@field close_window_and_swap? string|false Deprecated alias for close_window_with_save
---@field toggle_maximize? string|false Keymap for toggling maximization on the current window
---@field focus_or_create_left_window? string|false Keymap for focusing or creating a window to the left of the current window
---@field focus_or_create_below_window? string|false Keymap for focusing or creating a window below the current window
---@field focus_or_create_above_window? string|false Keymap for focusing or creating a window above the current window
---@field focus_or_create_right_window? string|false Keymap for focusing or creating a window to the right of the current window
---@field create_left_window? string|false Keymap for creating a window to the left of the current window
---@field create_below_window? string|false Keymap for creating a window below the current window
---@field create_above_window? string|false Keymap for creating a window above the current window
---@field create_right_window? string|false Keymap for creating a window to the right of the current window

---@class WindClipboardAIConfig
---@field file_begin_text string Text marker for file start in AI format
---@field content_begin_text string Text marker for content start in AI format
---@field file_end_text string Text marker for file end in AI format
---@field line_separator string Line separator in AI format
---@field separator? string Deprecated alias for line_separator
---@field include_path boolean Include file path in AI format
---@field include_filetype boolean Include file type in AI format
---@field include_line_count boolean Include line count in AI format

---@class WindClipboardConfig
---@field empty_filepath string Text to use when file has no path
---@field notify boolean Show notifications for clipboard operations
---@field ai WindClipboardAIConfig AI-friendly clipboard formatting options
---@field keymaps? WindClipboardKeymaps|false Clipboard keymaps configuration

---@class WindClipboardKeymaps
---@field yank_window? string|false Keymap prefix for yanking specific windows
---@field yank_current_window? string|false Keymap for yanking current window
---@field yank_current_window_ai? string|false Keymap for AI-formatted current window
---@field yank_windows_ai? string|false Keymap for AI-formatted all windows
---@field yank_filename? string|false Keymap for yanking filename

---@class WindConfig
---@field windows WindWindowsConfig Windows management configuration
---@field clipboard WindClipboardConfig Clipboard management configuration

-- Default configuration
---@type WindConfig
M.defaults = {
	windows = {
		excluded_bufnames = {},
		excluded_filetypes = { "help", "neo-tree", "notify" },
		max_windows = 9,
		zero_based_indexing = false,
		notify = true,
		keymaps = {
			focus_or_create_horizontal_window = "<leader>", -- Prefix
			focus_or_create_vertical_window = "<leader>v", -- Prefix
			swap_window = "<leader>x", -- Prefix
			close_window = "<leader>q", -- Prefix
			close_window_with_save = "<leader>z", -- Prefix
			toggle_maximize = "<leader>wm",
			focus_or_create_left_window = "<leader>wh",
			focus_or_create_below_window = "<leader>wj",
			focus_or_create_above_window = "<leader>wk",
			focus_or_create_right_window = "<leader>wl",
			create_left_window = "<leader>wH",
			create_below_window = "<leader>wJ",
			create_above_window = "<leader>wK",
			create_right_window = "<leader>wL",
		},
	},

	clipboard = {
		empty_filepath = "[No Name]",
		notify = true,
		ai = {
			file_begin_text = "=== FILE BEGIN ===",
			content_begin_text = "--- CONTENT ---",
			file_end_text = "=== FILE END ===",
			line_separator = "\n",
			include_filetype = true,
			include_line_count = true,
			include_path = true,
		},
		keymaps = {
			yank_current_window = "<leader>ya",
			yank_current_window_ai = "<leader>y#",
			yank_windows_ai = "<leader>y*",
			yank_filename = "<leader>yn",
		},
	},
}

-- Merged configuration table
M._config = nil

--- Normalize deprecated configuration options before merging.
---@param opts WindConfig|nil
---@return WindConfig|nil
local function normalize_opts(opts)
	if not opts then
		return opts
	end

	local normalized = nil

	if
		opts.windows
		and opts.windows.keymaps
		and opts.windows.keymaps.close_window_and_swap ~= nil
		and opts.windows.keymaps.close_window_with_save == nil
	then
		normalized = normalized or deepcopy(opts)
		normalized.windows.keymaps.close_window_with_save = normalized.windows.keymaps.close_window_and_swap
	end

	if
		opts.clipboard
		and opts.clipboard.ai
		and opts.clipboard.ai.separator ~= nil
		and opts.clipboard.ai.line_separator == nil
	then
		normalized = normalized or deepcopy(opts)
		normalized.clipboard.ai.line_separator = normalized.clipboard.ai.separator
	end

	return normalized or opts
end

--- Setup function to receive the merged config
function M.setup(opts)
	M._config = tbl_deep_extend("force", M.defaults, normalize_opts(opts) or {})
end

--- Get the current configuration
function M.get()
	return M._config or M.defaults
end

--- Get specific section
function M.get_section(section)
	local config = M.get()
	return config[section] or {}
end

return M
