-- Localized vim variables
local tbl_deep_extend = vim.tbl_deep_extend

local M = {}

---@class WindWindowsConfig
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
---@field close_window_and_swap? string|false Keymap prefix for close-and-swap
---@field create_horizontal_window_after_current? string|false Keymap for creating horizontal window after current
---@field create_horizontal_window_before_current? string|false Keymap for creating horizontal window before current
---@field create_vertical_window_after_current? string|false Keymap for creating vertical window after current
---@field create_vertical_window_before_current? string|false Keymap for creating vertical window before current

---@class WindClipboardAIConfig
---@field file_begin_text string Text marker for file start in AI format
---@field content_begin_text string Text marker for content start in AI format
---@field file_end_text string Text marker for file end in AI format
---@field separator string Separator between files in AI format
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
		excluded_filetypes = { "help", "neo-tree", "notify" },
		max_windows = 9,
		zero_based_indexing = false,
		notify = true,
		keymaps = {
			focus_or_create_horizontal_window = "<leader>", -- Prefix
			focus_or_create_vertical_window = "<leader>v", -- Prefix
			swap_window = "<leader>x", -- Prefix
			close_window = "<leader>q", -- Prefix
			close_window_and_swap = "<leader>z", -- Prefix
			create_horizontal_window_after_current = "<leader>wh",
			create_horizontal_window_before_current = "<leader>wH",
			create_vertical_window_after_current = "<leader>wv",
			create_vertical_window_before_current = "<leader>wV",
		},
	},

	clipboard = {
		empty_filepath = "[No Name]",
		notify = true,
		ai = {
			file_begin_text = "=== FILE BEGIN ===",
			content_begin_text = "--- CONTENT ---",
			file_end_text = "=== FILE END ===",
			separator = "\n",
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

--- Setup function to receive the merged config
function M.setup(opts)
	M._config = tbl_deep_extend("force", M.defaults, opts or {})
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
