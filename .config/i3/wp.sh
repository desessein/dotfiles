#!/bin/sh

killall xwinwrap

sleep 0.3

xwinwrap -ov -ni -g 1920x1080+0+0 -- mpv -wid WID -loop ~/Videos/Hidamari/wp.mp4 &
xwinwrap -ov -ni -g 1920x1080+1920+0 -- mpv -wid WID -loop ~/Videos/Hidamari/wp1.mp4 &

