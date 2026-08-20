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

    /**
     * Night Glass accent split. `mark` is the UI accent the palette guarantees
     * 4.5:1 against the pill surface; `glow` is the filament light that effects
     * stack and is never text. Both fall back to the pre-split fields, because
     * the cache is only rewritten on the next wallpaper change and a
     * colors.json written before the split has neither key. The guard is on
     * length, not on undefined: an absent key leaves the JsonAdapter property
     * at its default and matugen can also write an empty string, so only a
     * non-empty value counts as present.
     */
    readonly property string mark: adapter.mark.length > 0 ? adapter.mark : primary
    readonly property string glow: adapter.glow.length > 0 ? adapter.glow : primaryContainer

    /**
     * Status accents: passthrough, no in-Dyn fallback. Theme.danger/warning/ok
     * does the empty-string check itself (against a curated hex, not another
     * palette field), so these mirror mark/glow's camelCase-alias pattern
     * without their length-guarded fallback.
     */
    readonly property string danger: adapter.danger
    readonly property string warning: adapter.warning
    readonly property string ok: adapter.ok

    /**
     * There is deliberately no `brightSurface` here any more. It existed for
     * exactly one consumer — the floor `Theme.surfAlpha` put under glass on a
     * bright wallpaper — and that floor is gone: glass now composites at the
     * user's own window-background opacity, which nothing derived from the
     * wallpaper gets to override. With its only reader retired the property was
     * a wallpaper-brightness signal answering a question nobody asked.
     */

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/capsuleos/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string surface: "#1b0c0b"
            property string surface_container: "#291311"
            property string surface_container_low: "#23100e"
            property string surface_container_high: "#321715"
            property string surface_container_highest: "#3f1d1a"
            property string primary: "#b87735"
            property string primary_container: "#93571a"
            property string on_primary_container: "#ebdbcb"
            property string outline: "#9a463f"
            property string outline_variant: "#6c322c"
            property string cream: "#e7e6e4"
            property string bright: "#f8f7f7"
            property string subtle: "#bfbab5"
            property string dim: "#918a83"
            property string faint: "#76706b"
            property string icon_dim: "#d2cfcb"
            property string tick_rest: "#c4bfba"
            // Empty by default so a pre-split colors.json falls back above
            // instead of pinning the curated hexes onto a wallpaper palette.
            property string mark: ""
            property string glow: ""
            // Empty by default so a pre-status colors.json falls back in Theme
            // instead of pinning stale reds onto a wallpaper palette.
            property string danger: ""
            property string warning: ""
            property string ok: ""
        }
    }
}
