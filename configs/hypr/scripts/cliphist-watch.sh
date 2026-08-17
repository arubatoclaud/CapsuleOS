#!/bin/sh
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/cliphist-watch.lock"
flock -n 9 || exit 0

pgrep -f "wl-paste --type text --watch cliphist" >/dev/null || wl-paste --type text --watch cliphist store &
pgrep -f "wl-paste --type image --watch cliphist" >/dev/null || wl-paste --type image --watch cliphist store &
