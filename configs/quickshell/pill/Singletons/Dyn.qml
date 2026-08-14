pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live wallpaper-derived palette. matugen writes a small colour JSON on every
 * wallpaper change (via wallcolors.py) and this singleton watches it, so the
 * tokens update the moment the wallpaper does. Theme reads these only while the
 * dynamic-palette flag is on; otherwise the curated washi hex wins. Defaults are
 * a warm fallback so a missing file still yields a usable scheme. Surfaces and
 * the accent ramp come from here; text stays locked in Theme for contrast.
 */
Singleton {
    id: root

    readonly property string surface: adapter.surface
    readonly property string surfaceContainer: adapter.surface_container
    readonly property string surfaceContainerLow: adapter.surface_container_low
    readonly property string surfaceContainerHigh: adapter.surface_container_high
    readonly property string surfaceContainerHighest: adapter.surface_container_highest
    readonly property string primary: adapter.primary
    readonly property string primaryContainer: adapter.primary_container
    readonly property string onPrimaryContainer: adapter.on_primary_container
    readonly property string outline: adapter.outline
    readonly property string outlineVariant: adapter.outline_variant
    readonly property string cream: adapter.cream
    readonly property string bright: adapter.bright
    readonly property string subtle: adapter.subtle
    readonly property string dim: adapter.dim
    readonly property string faint: adapter.faint
    readonly property string iconDim: adapter.icon_dim
    readonly property string tickRest: adapter.tick_rest

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/pillos/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string surface: "#0e131c"
            property string surface_container: "#10151f"
            property string surface_container_low: "#10151f"
            property string surface_container_high: "#161c28"
            property string surface_container_highest: "#161c28"
            property string primary: "#ffb454"
            property string primary_container: "#c2410c"
            property string on_primary_container: "#f2f6fb"
            property string outline: "#263042"
            property string outline_variant: "#10151f"
            property string cream: "#d5dce6"
            property string bright: "#f2f6fb"
            property string subtle: "#a4aebc"
            property string dim: "#7d8797"
            property string faint: "#5d6570"
            property string icon_dim: "#b8c2cf"
            property string tick_rest: "#aab6c6"
        }
    }
}
