-- Localized vim variables
local tbl_deep_extend = vim.tbl_deep_extend

local M = {}

-- Default configuration
M.defaults = {
	windows = {
		excluded_filetypes = { "help", "neo-tree" },
		index_help_windows = false,
		max_windows = 9,
		zero_based_indexing = false,
		notify = true,
		keymaps = {
			focus_or_create_horizontal_window = "<leader>", -- Prefix
			focus_or_create_vertical_window = "<leader>v", -- Prefix
			swap_window = "<leader>x", -- Prefix
			close_window = "<leader>q", -- Prefix
			close_window_and_swap = "<leader>z", -- Prefix
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
