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
     * True when the wallpaper is bright enough that the palette has lifted the
     * surface to the top of its band. wallcolors.py is dark-only now and maps
     * wallpaper mean lightness onto the surface's HSL lightness in
     * [DEPTH_MIN, DEPTH_MAX] = [0.06, 0.16], so the surface lightness IS the
     * wallpaper-brightness signal that the dropped `light` flag used to carry;
     * > 0.13 is the brightest fifth of that band. Theme floors the glass alpha
     * on it so a bright wallpaper cannot composite through the pill and eat
     * the mark's contrast (see Theme.surfAlpha).
     *
     * Gated on the raw `mark` field because the threshold only means something
     * inside the Night Glass band: a pre-split colors.json comes off the old
     * [0.045, 0.20] ramp, where 0.13 is an ordinary dark surface, and reading
     * it through this threshold would floor the alpha on palettes that never
     * asked for it. No mark field, no claim.
     */
    readonly property bool brightSurface: adapter.mark.length > 0 && surface.length > 0
                                          && Qt.color(surface).hslLightness > 0.13

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
            property string surface_container_highest: "#2e3a50"
            property string primary: "#ffb454"
            property string primary_container: "#c2410c"
            property string on_primary_container: "#ffcf8f"
            property string outline: "#3a4658"
            property string outline_variant: "#263042"
            property string cream: "#d5dce6"
            property string bright: "#f2f6fb"
            property string subtle: "#a4aebc"
            property string dim: "#7d8797"
            property string faint: "#5d6570"
            property string icon_dim: "#b8c2cf"
            property string tick_rest: "#aab6c6"
            // Empty by default so a pre-split colors.json falls back above
            // instead of pinning the curated hexes onto a wallpaper palette.
            property string mark: ""
            property string glow: ""
        }
    }
}
