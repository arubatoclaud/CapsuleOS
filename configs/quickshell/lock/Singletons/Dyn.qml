pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper-derived palette, same matugen JSON the pill watches, trimmed to
 * the tokens the lock consumes. Never source anything from on_primary_container:
 * the pill's token for it reads empty and collapses to black (the pill learned
 * this the hard way). The cause is not matugen, as long assumed, but the name:
 * QML parses `property T onFoo: expr` as a handler for `foo` whenever a member
 * named `foo` exists on the same object, so `onPrimaryContainer` next to
 * `primaryContainer` never gets its binding. Measured on the live palette,
 * Task 2. Keep the rule and never name a token `on<ExistingToken>`.
 */
Singleton {
    readonly property string primary: adapter.primary
    readonly property string cream: adapter.cream
    readonly property string bright: adapter.bright
    readonly property string dim: adapter.dim
    /**
     * Night Glass accent split: `mark` for UI, `glow` for filament light. Both
     * fall back to the pre-split fields, because the cache is only rewritten on
     * the next wallpaper change and a colors.json written before the split has
     * neither key. Length, not undefined, is the test: an absent key leaves the
     * adapter property at its default and matugen can also write the key empty
     * (the same failure the header warns about), so only a non-empty value
     * counts. `glow`'s fallback needs primary_container, which the lock does
     * not otherwise render, so it stays private to the adapter rather than
     * becoming a token.
     */
    readonly property string mark: adapter.mark.length > 0 ? adapter.mark : primary
    readonly property string glow: adapter.glow.length > 0 ? adapter.glow : adapter.primary_container

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/pillos/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string primary: "#ffb454"
            property string cream: "#d5dce6"
            property string bright: "#f2f6fb"
            property string dim: "#7d8797"
            property string primary_container: "#c2410c"
            // Empty by default so a pre-split colors.json takes the fallbacks.
            property string mark: ""
            property string glow: ""
        }
    }
}
