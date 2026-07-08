# Renders the README demo without a human at the keyboard.
# Requires vhs (brew install vhs). Run from the repo root:
#   vhs demo/wind.tape

Output demo/demo.gif
Output demo/demo.mp4

Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 20
Set Width 1400
Set Height 800
Set Padding 16
Set Framerate 24

Hide
Type "nvim -u demo/init.lua -i NONE lua/wind/engine.lua"
Enter
Sleep 2.5s
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

# Hesitate, see the numbers, go.
Type " v"
Sleep 1.5s
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
