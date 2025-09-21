<!-- Header -->
<div align="center">
    <h1>Wind.nvim</h1>
    <p>
        Move as fast as wind
        <br />
        <a href="#about">About</a>
        ·
        <a href="#installation">Installation</a>
        ·
        <a href="#configuration">Configuration</a>
        ·
        <a href="#default-keymaps">Default Keymaps</a>
        ·
        <a href="#contributing">Contributing</a>
    </p>
</div>

## About

Wind.nvim is a Neovim plugin to provide advanced window management and clipboard utilities. It allows you to quickly focus / create windows by index, swap windows, and yank all windows at once.

It works by indexing your windows from left-to-right and then top-to-bottom like these examples:

    Example 1:
    +----------------+  +----------------+  +----------------+  +----------------+
    | Window 1       |  | Window 2       |  | Window 3       |  | Window 4       |
    | Neo-tree       |  | file 1         |  | file 2         |  | help           |
    | (excluded)     |  | (indexed)      |  | (indexed)      |  | (excluded)     |
    +----------------+  +----------------+  +----------------+  +----------------+
                        index: 1            index: 2

    Example 2:
    +----------------+  +----------------+  +------------------------------------+
    | Window 1       |  | Window 2       |  | Window 3                           |
    | Neo-tree       |  | file 1         |  | file 2                             |
    | (excluded)     |  | (indexed)      |  | (indexed)                          |
    +----------------+  +----------------+  +------------------------------------+
                        index: 1            index: 2

                                            +----------------+  +----------------+
                                            | Window 4       |  | Window 5       |
                                            | file 3         |  | file 4         |
                                            | (indexed)      |  | (indexed)      |
                                            +----------------+  +----------------+
                                            index: 3            index: 4

Wind.nvim eliminates the cognitive overhead of window navigation by letting you jump directly to your destination instead of calculating directional movements.

For simplicity, the plugin will always create new windows after the last indexed window. As a result, windows will always follow the same direction towards the bottom-right.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended):

```lua
{
    "rvaccone/wind.nvim",
    ---@type WindConfig
    opts = {}
}
```

## Configuration

Here is the default configuration:

```lua
{
	windows = {
		excluded_filetypes = { "help", "neo-tree" },
		index_help_windows = false,
		max_windows = 9,
		zero_based_indexing = false,
		notify = true,
		keymaps = {
			focus_or_create_horizontal_window = "<leader>",
			focus_or_create_vertical_window = "<leader>v",
			swap_window = "<leader>x",
			close_window = "<leader>q",
			close_window_and_swap = "<leader>z",
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
```

Use `:h wind` for more information about each configuration option. However, here are some quick tips:

- You can disable all keymaps for a specific section by setting it to `false`.
- You can disable a keymap by setting it to `false`.

## Default Keymaps

By default, the plugin creates indexed keymaps (1-9) for window operations:

| Window keymaps              | Description                           |
| --------------------------- | ------------------------------------- |
| `<leader>1` - `<leader>9`   | Focus or create horizontal window 1-9 |
| `<leader>v1` - `<leader>v9` | Focus or create vertical window 1-9   |
| `<leader>x1` - `<leader>x9` | Swap current window with window 1-9   |
| `<leader>q1` - `<leader>q9` | Close window 1-9 without saving       |
| `<leader>z1` - `<leader>z9` | Close window 1-9 with saving          |

Clipboard keymaps:

| Clipboard keymaps | Description                      |
| ----------------- | -------------------------------- |
| `<leader>ya`      | Yank current window with path    |
| `<leader>y#`      | Yank current window in AI format |
| `<leader>y*`      | Yank all windows in AI format    |
| `<leader>yn`      | Yank current filename            |

All keymaps work in normal and visual modes.

## Contributing

Let's make Wind.nvim better together! Here are some ways you can help:

**Bug Reports & Feature Requests:**

- Open an issue on GitHub with clear reproduction steps
- Check existing issues first to avoid duplicates

**Pull Requests:**

- Fork the repository and create a feature branch
- Update documentation as needed

**Ideas for Improvements:**

- Better window creation
- Timeout to show window indexes
- Add new window movement commands
- Animations for window operations
- Clipboard option to allow for absolute paths
- Public API for window and clipboard operations
- See `:h wind` for more information for all of the above

Before contributing, please ensure your changes align with the plugin's core philosophy and design.
