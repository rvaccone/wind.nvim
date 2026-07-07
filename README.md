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
        <a href="#keymaps">Keymaps</a>
        ·
        <a href="#breaths">Breaths</a>
        ·
        <a href="#configuration">Configuration</a>
    </p>
</div>

## About

Windows with addresses. Layouts with history. You name where you want to be —
never how to get there.

Wind gives every window a number, ordered by its place on screen (left to
right, top to bottom by default), and every operation takes that number as its
destination: focus it, move to it, swap with it, close it. There are no
directional commands — no "focus left", no "move down" — because a route is
something you compute, and a destination is something you already know.

    +----------------+  +----------------+  +----------------+
    | neo-tree       |  | window 1       |  | window 2       |
    | (invisible     |  |                |  |                |
    |  to wind)      |  |                |  +----------------+
    |                |  |                |  | window 3       |
    +----------------+  +----------------+  +----------------+

- `<leader>2` focuses window 2. If it doesn't exist, one window is created
  beside the one you're in — so `<leader>9` always means "new window here".
- `<leader>w` shows number badges on every window, then one digit moves your
  window there while the others shift around it.
- `<leader>wm` zooms the current window into a full-screen lens. Navigation
  moves the lens; the layout underneath cannot be disturbed.
- Every structural change is recorded: `<leader>wu` / `<leader>wr` undo and
  redo layout changes. Buffers are never touched — layout undo cannot lose
  work, by construction.
- A layout worth returning to can be **held** as a breath and returned to by
  number, long after you've torn the windows down.

Wind requires Neovim 0.10+.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "rvaccone/wind.nvim",
    ---@type WindConfig
    opts = {},
}
```

> [!NOTE]
> This is wind.nvim v1, a ground-up redesign with breaking changes. To stay
> on the previous design, pin `version = "v0.1.0"`.

## Keymaps

Everything is verb + destination. `<leader>1–9` are plain mappings; every
other family is a single trigger that reveals number badges and reads one
key.

| Keys                      | Action                                              |
| ------------------------- | --------------------------------------------------- |
| `<leader>1–9`             | Focus window n / create beside current              |
| `<leader>v` + `1–9`       | Focus window n / create stacked beside current      |
| `<leader>w` + `1–9`       | Move current window to n; windows between shift     |
| `<leader>x` + `1–9`       | Swap current window with n                          |
| `<leader>q` + `1–9`       | Close window n                                      |
| `<leader>z` + `1–9`       | Save and close window n                             |
| `<leader>w` + `o`         | Only — close all other windows                      |
| `<leader>w` + `m`         | Zoom lens toggle                                    |
| `<leader>w` + `u` / `r`   | Layout undo / redo (count-aware: `3<leader>wu`)     |
| `<leader>w` + `=`         | Equalize window sizes                               |
| `<leader>w` + `+` / `-`   | Grow / shrink — keep tapping `+`/`-`, any key exits |
| `<leader>b` + `1–9`       | Return to breath n                                  |
| `<leader>b` + `b`         | Update the last-visited breath                      |
| `<leader>b` + `n`         | Hold a new breath                                   |
| `<leader>b` + `d` + `1–9` | Release breath n                                    |
| `` <leader>b` ``          | Alternate — toggle current ↔ previous layout        |

Press a trigger (`<leader>w`, `<leader>q`, …) and pause: a badge appears on
every window after a slight hesitation (`reveal.delay_ms`, default 150ms);
press a digit to act or anything else to cancel. Type at full speed and the
badges never appear at all — guidance is for the moment you hesitate, never
a cost on the moment you don't. Badges bloom in reading order and any
keypress dismisses them immediately. `:Wind reveal` shows them on demand.

Hesitating on the bare prefix works too: wind never maps `<leader>` itself
(that would steal it from which-key and every other leader mapping), it
only _observes_ it. In setups where a plugin like which-key consumes the
prefix immediately, badges appear right at `delay_ms` — spatial badges and
a which-key popup are complementary, not rivals.

The overlay inherits your colorscheme: every highlight is a default link
(`WindRevealBadge → NormalFloat`, `WindRevealBorder → FloatBorder`,
`WindRevealCurrent → Comment`), so themes and transparent backgrounds pass
straight through, exactly like a which-key window. Override the `WindReveal*`
groups to restyle.

Closing can never quit Neovim and never discards changes. Creation places
windows identically regardless of your `splitright` / `splitbelow` settings.

## Zoom

`<leader>wm` fills the screen with the current window. While zoomed:

- `<leader>1–9` switches which window fills the screen — the lens follows
  your focus instead of breaking the layout.
- Structural operations (create, close, move, resize, undo) are blocked
  until you exit. The layout you built is exactly as you left it.

## Layout history

Every structural action — create, close, move, swap, only, resize, breath
returns — lands in one history per tabpage. `<leader>wu` walks back,
`<leader>wr` walks forward, both accept counts.

Layout operations never write, close, or edit a buffer. Unsaved changes
survive any amount of undoing, closing, and restoring.

## Breaths

A breath is a held layout — fleeting by nature, kept only because you chose
to hold it.

1. Arrange windows for the task at hand.
2. `<leader>bn` holds it as the next breath — or just declare a destination:
   `<leader>b2` when breath 2 doesn't exist holds the current layout, the
   same way focusing a missing window creates one.
3. Tear everything down, work elsewhere.
4. `<leader>b2` rebuilds breath 2: same splits, same files, same cursor
   positions, rebuilt around your sidebars.

`<leader>bb` re-pins the last-visited breath to the current layout, and
`` <leader>b` `` bounces between the current layout and the one you last
jumped away from. Hesitating on `<leader>b` shows the breath card: one
column per breath — the number on top (`•` the breath you're on, `~` means
you've drifted from it) and each window's file beneath, in index order, so
the column doubles as a preview of what each digit will address.

Breaths record file paths, not buffer handles, so they restore cleanly even
after buffers close. Releasing a breath shifts the numbers down, exactly
like windows. Breath 1 is held automatically when Neovim starts.

## Configuration

The defaults:

```lua
{
    windows = {
        max = 9, -- hard ceiling; nine is the largest ambiguity-free address space
        flow = { horizontal = "right", vertical = "below" },
        excluded = {
            filetypes = { "neo-tree", "NvimTree", "netrw" },
            bufnames = {}, -- Lua patterns
        },
        notify = true,
    },
    breaths = {
        max = 9,
        auto_hold_first = true,
    },
    reveal = {
        enabled = true,
        delay_ms = 150, -- hesitation before guidance appears; 0 = instant
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
```

Keymaps are a prefix plus single characters on purpose: navigation, the
reveal, and every digit family derive from the same few keys and cannot
drift apart. Any verb can be disabled with `false`; `keymaps = false`
disables them all. Invalid configuration fails loudly at startup rather
than guessing.

`flow` controls which side new windows appear on and the direction indexing
reads the screen — set `horizontal = "left"` for right-to-left layouts.

Excluded windows (file trees and friends) are invisible to wind: never
indexed, never closed by `only`, never captured in breaths. Floating
windows are always invisible.

## Statusline

`wind.lualine_index()` returns the index of the window being drawn — active
or inactive — so every window can wear its number:

```lua
local function wind_index()
    local ok, wind = pcall(require, "wind")
    return ok and wind.lualine_index() or ""
end

require("lualine").setup({
    sections = { lualine_a = { wind_index } },
    inactive_sections = { lualine_a = { wind_index } },
})
```

The same function works in a plain `'statusline'` expression via
`v:lua` — it reads `g:statusline_winid`, so it is correct per window.

## API

```lua
local wind = require("wind")

wind.index_of()          -- index of the current window (or pass a win id)
wind.list()              -- ordered content windows
wind.lualine_index()     -- statusline component: index of the drawn window
wind.focus_or_create(n)  -- everything the keymaps do is callable
wind.undo() / wind.redo()
wind.hold() / wind.return_to(n)
```

`:Wind reveal` · `:Wind breaths` · `:Wind history` · `:Wind release <n>` ·
`:checkhealth wind`

## Design

The full design contract — principles, model, and the reasoning behind every
decision — lives in [DESIGN.md](DESIGN.md).

## Contributing

```sh
make test       # headless test suite
make fmt-check  # stylua
```
