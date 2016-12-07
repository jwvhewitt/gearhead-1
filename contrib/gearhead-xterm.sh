#!/bin/sh
# Start gearhead in an xterm, with proper aspect ratio.
# This does make text look funny to read at first, but you get used to it.
# Better alternatives involving code changes:
# * Use DECDWL.
#   Pro: Simple to implement.
#   Con: Can only be applied to whole lines, so single-width can only
#       be used for the messages at the bottom of the screen, not for
#       right-side-of-screen messages and popup dialogs.
# * Use double-width codepoint range starting at U+ff00.
#   Pro: Can be disabled for *all* text, and enabled only for the screen.
#   Con: Only ASCII. Currently fine, but disallows future new glyphs.

real_gearhead=${REAL_GEARHEAD:-/usr/games/gearhead}
font_name='mono'
# Pick something that gives you 60-70 lines on your screen and is readable.
# This works for me on a 768-pixel-tall (minus taskbars) screen.
font_size=7
# Most fonts are 8x16 or so. Double the width for them.
font_stretch=2

# I'm not sure if gearhead takes any command-line arguments yet, but
# just in case, build the xterm argument list backwards to preserve them.
set -- -e "$real_gearhead" "$@"
# Important bit: set a TrueType font with the proper ratio.
# Xterm usually uses bitmap fonts, but they can't be scaled.
# With most fonts, hinting must be disabled, or they will violate the
# bounding box. This often shows as the last line of an "m" disappearing.
# You *could* try to use 'XTerm*useClipping' or 'XTerm*scaleHeight', but
# I haven't had any luck with that.
set -- -fa "$font_name"':matrix='"$font_stretch"' 0 0 1:hinting=False' -fs "$font_size" "$@"
# Force xterm to draw the line-drawing characters itself. Most TTFs don't
# line up *quite* right, especially when stretched.
set -- +fbx "$@"
# Gearhead emits the 'bold' code when it really just wants to change
# the color to the "bright" version.
set -- -pc -xrm 'XTerm*allowBoldFonts:false' "$@"
# Set the palette explicitly. This is the VGA palette, but with darker grays.
# (otherwise it is really hard to tell height-2 from height-3 hills).
# Currently, gearhead uses:
# * default background, when it wants color0
# * default foreground, when it wants color7
# * bold + default foreground, when it wants color15
# The first two are easy enough to equalize, but the third is "interesting".
set -- -xrm 'XTerm*vt100.background: rgb:00/00/00' "$@" # dim black
set -- -xrm 'XTerm*vt100.color0: rgb:00/00/00' "$@"
set -- -xrm 'XTerm*vt100.color1: rgb:aa/00/00' "$@" # dim red
set -- -xrm 'XTerm*vt100.color2: rgb:00/aa/00' "$@" # dim green
set -- -xrm 'XTerm*vt100.color3: rgb:aa/55/00' "$@" # dim yellow -> brown
set -- -xrm 'XTerm*vt100.color4: rgb:00/00/aa' "$@" # dim blue
set -- -xrm 'XTerm*vt100.color5: rgb:aa/00/aa' "$@" # dim magenta
set -- -xrm 'XTerm*vt100.color6: rgb:00/aa/aa' "$@" # dim cyan
set -- -xrm 'XTerm*vt100.foreground: rgb:80/80/80' "$@" # dim white -> light gray
set -- -xrm 'XTerm*vt100.color7: rgb:80/80/80' "$@"
set -- -xrm 'XTerm*vt100.color8: rgb:40/40/40' "$@" # light black -> dark gray
set -- -xrm 'XTerm*vt100.color9: rgb:ff/55/55' "$@" # light red
set -- -xrm 'XTerm*vt100.color10: rgb:55/ff/55' "$@" # light green
set -- -xrm 'XTerm*vt100.color11: rgb:ff/ff/55' "$@" # light yellow
set -- -xrm 'XTerm*vt100.color12: rgb:55/55/ff' "$@" # light blue
set -- -xrm 'XTerm*vt100.color13: rgb:ff/55/ff' "$@" # light magenta
set -- -xrm 'XTerm*vt100.color14: rgb:55/ff/ff' "$@" # light cyan
set -- -xrm 'XTerm*vt100.colorBD: rgb:ff/ff/ff' "$@" # light white
set -- -xrm 'XTerm*vt100.color15: rgb:ff/ff/ff' "$@"
set -- -xrm 'XTerm*vt100.colorBDMode: true' "$@"
set -- -xrm 'XTerm*vt100.veryBoldColors: 0' "$@"

# Wait for window to be shown. Fixes a nondeterministic resize bug.
set -- -wf "$@"
# Or -fullscreen for a few more lines.
set -- -maximized "$@"
exec xterm "$@"
