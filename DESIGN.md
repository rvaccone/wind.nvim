# wind.nvim v1 — Design

> Windows with addresses. Layouts with history. You name where you want to be —
> never how to get there.

This document is the contract for the v1 rewrite. Every future feature and
keymap must survive the principles below; anything that answers "how do I get
there" instead of "where am I going" does not belong in this plugin.

## Principles

1. **Destination-first.** Every keymap names _what_ and _where_. No keymap
   performs a step of a route. This is why directional focus (`wh`/`wj`/…) is
   removed, not improved.
2. **The screen is the source of truth.** Windows are numbered geometrically
   (by screen position, in flow order) because the layout labels itself — a
   glance is a lookup. No permanent chrome (no winbar badges, no statusline
   requirement).
3. **Layout actions never touch buffers.** Closing, clearing, undoing, and
   restoring rearrange _frames_; buffers and their unsaved changes are never
   harmed. This is what makes layout undo reflexively safe.
4. **Frames don't move; contents flow through frames.** Move, swap, and
   restore permute buffers through the fixed split geometry in index order.
   This single rule makes every operation unambiguous in any layout.
5. **Fast path invisible, slow path guided.** Muscle-memory speed never sees
   the reveal; hesitation summons it. Any keypress dismisses instantly and
   acts immediately — guidance must never cost a millisecond.
6. **Precise objects, natural motion.** Badges are crisp, identical, sharply
   typeset. Their movement is organic: staggered bloom, eased fades. The
   aesthetic reference is precision hardware; the motion reference is air.
7. **Keymaps for reflexes, commands for rarities.** Frequent operations get
   keys. Rare operations (release, history inspection) get `:Wind` commands.
8. **Every mutation goes through the action dispatcher.** No module calls a
   layout-mutating `cmd()` directly. This is an architectural law, not a
   style preference — history, undo, and drift detection depend on it.
9. **Opinionated over configurable.** Max 9 windows (the largest
   ambiguity-free digit address space, and a practice limit). 1-based
   indexing only. Breaking changes are acceptable when the philosophy
   demands them; `v0.1.0` is tagged for anyone who disagrees.

## Terminology

Theme the nouns unique to wind's model; keep every verb literal.

| Term               | Meaning                                                                                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **window / index** | A content window and its geometric number (1–9), ordered by flow. Excluded windows (neo-tree, help, terminals…) are invisible to wind.                    |
| **flow**           | The configured direction layouts grow (default: right, below). Creation, index order, and overflow all obey it.                                           |
| **reveal**         | The transient badge overlay. Appears on hesitation after a prefix, instantly after `move`/`breath` prefixes.                                              |
| **gust**           | The reveal's motion: badges bloom in index order with a short stagger, sweeping in the flow direction.                                                    |
| **action**         | Any structural mutation (create, close, move, swap, only, resize-commit, return, …). Recorded in one history.                                             |
| **history**        | The session's ordered action log. Walked by layout undo/redo.                                                                                             |
| **breath**         | A held layout state — fleeting by nature, kept only because you chose to hold it. You **hold** a breath, **return** to it, **update** it, **release** it. |
| **alternate**      | The layout you most recently jumped away from. One register, toggled like `<C-^>`.                                                                        |
| **drift**          | Divergence between the current layout and the last breath you visited. Shown transiently in the reveal, never as permanent chrome.                        |
| **zoom**           | The lens: one window fills the screen while the layout persists beneath. Navigation moves the lens; structure is locked.                                  |

Considered and rejected for "breath": _still_ (film-frame pun, but no natural
verbs), _eddy_ (poetic, obscure), _waypoint_ (clear, not fleeting),
_bookmark/workspace_ (wrong model entirely). "Breath" wins because its verbs
are both idiomatic and precise: hold / return / release.

## The model

### Windows

- Content windows are indexed 1–9 in flow order (default: left→right,
  top→bottom, by `win_screenpos`). Excluded windows never index.
- `focus(n)`: jump to window n. If it doesn't exist, create **one** window
  **anchored at the current window**, on the flow side, orientation per
  keymap family (side-by-side for the plain digits, stacked for the `v`
  family). Notify the actual index created ("created window 2" even if you
  pressed 9).
  - Rationale: `move`/`swap` permute buffers through _fixed_ frames, so a
    frame below the middle of three columns is unreachable unless creation
    can anchor anywhere. Anchoring at the current window makes every
    geometry expressible by composition: `<leader>2` then `<leader>v9` reads
    "window 2; new stacked window here."
  - Consequences: on the last window this degenerates to v0's edge-append
    (the old behavior is the special case, not a change); `<leader>9` /
    `<leader>v9` become the universal "new window beside/below me" reflex —
    you never count windows to create.
  - If the current window is not a content window (e.g. focus is in
    neo-tree), anchor falls back to the last indexed window (flow edge).
- Creation uses explicit split modifiers (`leftabove`/`rightbelow` per flow)
  — never bare `:split`/`:vsplit` — so behavior is identical under any
  `splitright`/`splitbelow` configuration.
- `move(n)`: the current window's buffer inserts at index n; displaced
  buffers shift toward the vacated slot. Frames never move (Principle 4).
- `swap(n)`: exchange buffers of current and n. Provisional — may be removed
  if dogfooding shows `move` covers it.
- `close(n)` / `save_close(n)`: built on `:close` (never `:q` — closing a
  window must never quit Neovim). Focus returns to the window you were in.
  View state (`winsaveview`) is preserved wherever buffers move.
- `only`: close every other content window. Excluded windows untouched. One
  action; one undo restores everything.
- Max windows: 9. Hard ceiling, intentionally not raisable.

### Reveal

- Bare focus prefix (`<leader>`): badges appear after `hesitation_ms`
  (default 200) — fast presses never see them.
- `move` / `breath` prefixes: badges appear immediately (a number is the only
  possible continuation). Move shows badges on _other_ windows; breath shows
  small cards (number + held filenames + drift marker `*`).
- Badge object: small rounded float, centered per window, single bold digit,
  identical size everywhere. Current window's badge renders hollow/dim.
- Gust motion: ~15ms stagger in index order; fade in ~140ms ease-out; fade
  out ~220ms ease-in (`winblend` stepping). `reveal.animate = false` disables
  all motion. Dismissal on keypress is instant and unconditional.
- Implementation: `vim.on_key` watcher + timer. No which-key dependency.

### Actions & history

- Every mutation constructs an Action: `{ type, params, before, after }`
  where `before`/`after` are lightweight layout snapshots.
- One history per session (per tabpage initially — see Open Questions).
- `undo` / `redo` walk it, count-aware (`3<undo>`). They rearrange frames
  and re-show buffers; they never write, close, or edit a buffer.
- The scratch pattern is the acceptance test: create a window, glance,
  undo — total cost two keymaps, zero risk.

### Breaths

- **hold**: pin the current layout as a breath (lowest free number 1–9).
- **return(n)**: apply breath n. The layout you left becomes the alternate.
- **update**: re-pin the **last-visited** breath to the current layout
  (`commit -a` for layouts). Explicit, one keymap — drift is deliberate
  until you say otherwise.
- **release(n)**: forget breath n. Verb + destination like the close-window
  family (`<leader>bd3`); also `:Wind release 3` for scripting.
- **return(n) when breath n doesn't exist**: notify quietly, create nothing.
  Unlike window creation (visible immediately, undoable), an implicitly held
  breath is invisible state — a phantom that pollutes the reveal cards. With
  `hold` on its own key, deliberate creation has a home; implicit creation
  could only ever produce accidents.
- **alternate**: one register, set by jump-class actions (return, only,
  large undo jumps). Toggle swaps current ↔ alternate. Returning to the
  breath you are already on also bounces to the alternate.
- Session starts with **breath 1 auto-held** from the initial layout, so
  `update` and the alternate toggle always have a target.
- Breath numbers are **stable** (unlike geometric window numbers). This is
  principled, not inconsistent: windows are labeled by the visible screen;
  breaths are invisible when you're not in them, so they need stable names —
  the reveal cards bridge the gap.
- Snapshots record **file path + cursor + geometry** for content windows
  only — never buffer handles. Restore re-`:edit`s paths; ephemeral buffers
  (terminals, unnamed) are excluded by construction, so a breath can't
  resurrect a corpse.

### Zoom (the lens)

- Toggle fills the screen with the current window; the layout persists
  beneath, untouched.
- While zoomed: `focus(n)` moves the lens (window n now fills the screen).
  Structural operations — create, close, move, swap, only, resize, undo/redo,
  return — are **blocked with a quiet notice**. Small state machine, no
  broken states.
- Toggling off restores the exact prior view. Returning to a breath or
  leaving the tabpage exits the lens first.

### Resize

- `equalize`: structural proportional reset (native `wincmd =` semantics — a
  half-and-two-quarters layout equalizes to half-and-two-quarters).
- `grow` / `shrink`: operate on the current window in the smart dimension
  (width if it has horizontal siblings, height if vertical, both if both).
  First press enters a **transient submode**: `+`/`-` repeat the nudge, any
  other key exits and executes normally. The full resize session commits to
  history as one action.

## Keymaps

Everything is verb + destination. `1–9` maps are generated per digit.

| Keys                        | Action                                                                  |
| --------------------------- | ----------------------------------------------------------------------- |
| `<leader>1–9`               | Focus window n / create beside current window (side-by-side, flow side) |
| `<leader>v1–9`              | Focus window n / create beside current window (stacked, flow side)      |
| `<leader>w1–9`              | Move current window to n (shift)                                        |
| `<leader>x1–9`              | Swap current window with n _(provisional)_                              |
| `<leader>q1–9`              | Close window n                                                          |
| `<leader>z1–9`              | Save & close window n                                                   |
| `<leader>wo`                | Only — close all other content windows                                  |
| `<leader>wm`                | Zoom lens toggle                                                        |
| `<leader>wu` / `<leader>wr` | Layout undo / redo (count-aware)                                        |
| `<leader>w=`                | Equalize                                                                |
| `<leader>w+` / `<leader>w-` | Grow / shrink (enters resize submode)                                   |
| `<leader>b1–9`              | Return to breath n                                                      |
| `<leader>bb`                | Update the last-visited breath (the daily verb gets the double-tap)     |
| `<leader>bn`                | Hold a new breath                                                       |
| `<leader>bd1–9`             | Release breath n                                                        |
| `` <leader>b` ``            | Alternate — toggle current ↔ previous layout                            |

Commands: `:Wind reveal`, `:Wind history`, `:Wind breaths`,
`:Wind release <n>`, plus `:checkhealth wind`.

Removed: `wh/wj/wk/wl`, `wH/wJ/wK/wL` (directional focus/create — process,
not destination), send-window-to-set (modify the present, update the breath).

## Configuration (schema sketch)

```lua
{
  windows = {
    max = 9,                       -- ceiling; cannot exceed 9
    flow = { horizontal = "right", vertical = "below" },
    excluded = {
      filetypes = { "help", "neo-tree", "notify" },
      bufnames = {},               -- Lua patterns
    },
    notify = true,
  },
  reveal = {
    hesitation_ms = 200,
    animate = true,
  },
  breaths = {
    auto_hold_first = true,
  },
  keymaps = { ... },               -- any entry: string|false; table: false disables all
}
```

Breaking changes from v0: flat `excluded_*` keys → nested `excluded`;
`zero_based_indexing` removed; `max_windows` → `windows.max` (≤ 9); clipboard
section removed entirely; all keymap names renewed.

## Architecture

```
lua/wind/
  init.lua        -- setup, :Wind command router
  config.lua      -- schema, defaults, validation (hard errors, not guesses)
  engine.lua      -- index, flow-aware splits, content-window predicate
  actions.lua     -- THE dispatcher: Action records, history, undo/redo
  snapshot.lua    -- layout serialize/restore (winlayout tree walk)
  breath.lua      -- held states, alternate register, drift
  reveal.lua      -- badges, gust animation, on_key hesitation watcher
  zoom.lua        -- lens state machine, structural lockout
  resize.lua      -- grow/shrink submode, equalize
  keymaps.lua     -- binding generation from config
  health.lua      -- :checkhealth wind
```

Dependency rule: `engine` and `snapshot` know nothing about keymaps or UI.
`actions` wraps `engine`. Everything user-facing calls `actions`, never
`engine` (Principle 8).

Snapshot format (per breath / per action edge):

```lua
{
  tree = { "row", { "leaf", ... } | { "col", ... } },  -- winlayout() shape
  leaves = { { path = "src/a.ts", cursor = {12,4}, width = 0.5, height = 1.0 } },
}
```

Sizes are stored as fractions of the content area, so restores survive
terminal resizes and the presence/absence of excluded side windows.

## Build phases

1. **Engine + dispatcher + correctness.** Flow-aware explicit splits, safe
   close, focus restoration, view preservation. Action records from day one
   (even before undo ships). Test harness rebuilt alongside.
2. **Reveal.** Badges, gust, hesitation watcher.
3. **Move-with-shift** (+ swap on the new engine).
4. **Zoom lens** with structural lockout.
5. **Snapshot spike.** Serialize/restore with a real test suite — this is
   the hardest code in the plugin and gets proven before it gets keymaps.
6. **Undo/redo surface**, then **breaths** (hold/return/update/alternate/drift).
7. **Resize** submode + equalize.
8. **Release.** CI (test + stylua on multiple Neovim versions), checkhealth,
   docs, README rewrite + GIF, `v1.0.0`.

## Removed from scope

- **Clipboard module** — out of identity. The one daily-useful piece
  (yank buffer with path) belongs in a personal config; migration note will
  include the snippet.
- Directional focus/create keymaps; flip/cycle transformations;
  send-window-to-set; winbar/statusline badges; >9 windows; 0-based indexing.

## Open questions

- Does `swap` survive dogfooding once `move` exists?
- History scope: per tabpage or global? (Leaning per tabpage; zoom is the
  only tab consumer today and it's excluded from indexing.)
- Cross-session breath persistence (serialize to disk per project) — v1.x,
  not v1.0.
