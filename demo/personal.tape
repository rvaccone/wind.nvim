# Renders the demo inside the author's real Neovim config (theme, statusline,
# which-key). Run from the repo root:
#   vhs demo/personal.tape
#
# The repo is copied to /tmp/wind-demo first so the persistent breath store
# for the real project is never touched (stores are keyed by cwd).

Output demo/demo.gif
Output demo/demo.mp4

Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 20
Set Width 1400
Set Height 800
Set Padding 16
Set Framerate 20

Hide
Type "rm -rf /tmp/wind-demo && cp -R . /tmp/wind-demo && cd /tmp/wind-demo && clear"
Enter
Type "nvim lua/wind/engine.lua"
Enter
Sleep 4s
# The demo is about windows; give them the whole frame. Delete to keep the tree.
Type ":Neotree close"
Enter
Sleep 500ms
Type ":echo ''"
Enter
Show

Sleep 1.5s

# Create window 2 from the root prefix.
Type " 2"
Sleep 800ms
Type ":e lua/wind/breath.lua"
Enter
Sleep 1s

# Hesitate on the stacked family: the badges appear, then 3 creates below.
Type " v"
Sleep 1.5s
Type "3"
Sleep 800ms
Type ":e lua/wind/reveal.lua"
Enter
Sleep 1.2s

# Hesitate on the bare prefix, see the numbers, go.
Type " "
Sleep 800ms
Type "1"
Sleep 1s

# Wreck the layout, then undo the layout itself.
Type " wo"
Sleep 1.5s
Type " wu"
Sleep 2s

# Hold this layout as breath 1.
Type " bb"
Sleep 2s

# Drift somewhere else and hold that as breath 2.
Type " wo"
Sleep 600ms
Type ":e DESIGN.md"
Enter
Sleep 1s
Type " bn"
Sleep 1.2s

# Hesitate on the breath family: the card shows both breaths. Return to 1.
Type " b"
Sleep 2.5s
Type "1"
Sleep 2s

# The numbers are muscle memory now.
Type " b2"
Sleep 1.5s
Type " b1"
Sleep 3.5s

Hide
Type ":qa!"
Enter
Type "rm -rf /tmp/wind-demo ~/.local/share/nvim/wind/*wind-demo*"
Enter
