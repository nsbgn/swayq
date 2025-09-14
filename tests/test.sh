#!/bin/sh
# We really need tests. This is the beginning.

WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 SWAYSOCK=tmp sway -c empty &
PID=$!

echo $PID
sleep 1
SWAYSOCK=tmp swayq ipc get_tree
kill $PID
