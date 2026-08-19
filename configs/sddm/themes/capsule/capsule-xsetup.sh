#!/bin/sh
# The panel is portrait-native (1600x2560) but the chassis mounts it rotated;
# Hyprland corrects with transform 1, this is the X11 greeter's equivalent.
# If the greeter ever comes up upside-down, swap "right" for "left".
xrandr --output eDP-1 --rotate right
