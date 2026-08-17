#!/usr/bin/env bash
set -euo pipefail
umask 077

verb=$1
out=$2
out=${out//[^A-Za-z0-9_.@:x+-]/}

run_dir="${XDG_RUNTIME_DIR:-/tmp}"
old_file="$run_dir/pillos-display-$out.old"
pending_file="$run_dir/pillos-display-$out.pending"

snapshot_old() {
    spec=$(hyprctl monitors -j | jq -r --arg o "$out" '
        .[] | select(.name == $o) |
        "hl.monitor({ output = \"" + .name +
        "\", mode = \"" + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate*1000|round)/1000|tostring) +
        "\", position = \"" + (.x|tostring) + "x" + (.y|tostring) +
        "\", scale = " + (.scale|tostring) + " }) return \"ok\""')
    [ -n "$spec" ] || return 1
    printf '%s' "$spec" > "$old_file"
}

case "$verb" in
apply)
    mode=$3
    position=$4
    scale=$5
    mode=${mode//[^A-Za-z0-9_.@:x+-]/}
    position=${position//[^A-Za-z0-9_.@:x+-]/}
    if [ ! -e "$old_file" ]; then
        snapshot_old || exit 1
    fi
    token=$(date +%s%N)
    printf '%s' "$token" > "$pending_file"
    new_spec="hl.monitor({ output = \"$out\", mode = \"$mode\", position = \"$position\", scale = $scale }) return \"ok\""
    hyprctl eval "$new_spec" >/dev/null 2>&1 || true
    setsid -f sh -c '
        pending=$1
        old=$2
        token=$3
        sleep 14
        if [ "$(cat "$pending" 2>/dev/null)" = "$token" ]; then
            hyprctl eval "$(cat "$old")" >/dev/null 2>&1
            rm -f "$pending" "$old"
        fi
    ' sh "$pending_file" "$old_file" "$token" >/dev/null 2>&1 || true
    ;;
keep)
    rm -f "$pending_file" "$old_file"
    ;;
revert)
    if [ -e "$old_file" ]; then
        hyprctl eval "$(cat "$old_file")" >/dev/null 2>&1 || true
    fi
    rm -f "$pending_file" "$old_file"
    ;;
*)
    exit 2
    ;;
esac
