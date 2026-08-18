pragma Singleton
import QtQuick
import Quickshell

/**
 * Pill palette. Two sources: the curated night-bridge hex below is the identity
 * and the default, used whenever the dynamic-palette flag is off. With the flag
 * on, the surfaces and the whole accent ramp follow the wallpaper through the
 * matugen-fed `Dyn` singleton, while the text family, light veils and shadow
 * stay locked here so copy keeps its contrast on any generated background. Each
 * token is a single ternary, so static mode renders byte-identical to the fixed
 * theme and only the colours that should breathe with the wallpaper do.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    /**
     * Material preset: glass = bright translucent, frost = dark translucent,
     * ink = flat opaque. Alpha rides the surface tokens so every surface
     * follows; Flags.pillOpacity still multiplies on top at the window level.
     */
    readonly property string material: Flags.material
    readonly property real baseAlpha: material === "glass" ? 0.62 : material === "ink" ? 1.0 : 0.86
    /**
     * Whether the material wants the compositor blurring what sits behind the
     * pill: glass and frost are translucent and read as frosted glass over the
     * wallpaper, ink is flat opaque and blurring behind it only costs GPU time.
     * The ONE definition of that derivation — Store applies it to
     * decoration.lua's `pill-blur` layer_rule whenever the material changes,
     * and no flag stores it. It lives here, next to the other
     * material-derived surface values, because it is a rendering consequence
     * of the material and not a stored flag of its own (the flag it replaces
     * was audit P0-4: a second control over one piece of state).
     *
     * The predicate is a function as well as a property because Store has to
     * ask it about a material it is in the middle of storing: a JsonAdapter
     * property read back in the same turn it was written still reports the
     * previous value, so `Theme.pillBlur` would answer about the material being
     * replaced. Store passes the incoming value to `blursBehind` instead, and
     * reads the property only when it is not writing.
     */
    function blursBehind(m) {
        return m !== "ink";
    }
    readonly property bool pillBlur: Theme.blursBehind(Theme.material)
    /**
     * Translucent surfaces composite the wallpaper through the pill, and on a
     * bright wallpaper that eats the accent's contrast. The palette guarantees
     * the mark 4.5:1 against the pill card as it composites at SURF_ALPHA =
     * 0.86, so anything thinner than that is the renderer's problem, not the
     * palette's (Task 1 review, Important-2: the floor this replaces was
     * load-bearing on glass, where alpha 0.62 lets far too much wallpaper
     * through). Glass is the only material under 0.86, so its alpha is floored
     * back to 0.85 exactly when the wallpaper is bright enough to matter:
     * Dyn.brightSurface, the top of the dark-only depth band, which is where
     * the dropped `light` flag's job went. Dark wallpapers keep the full glass
     * thinness — the floor is a rescue, not the resting state.
     */
    readonly property real surfAlpha: (dyn && Dyn.brightSurface) ? Math.max(baseAlpha, 0.85) : baseAlpha

    /**
     * Conversion factor for the handful of sites that hard-pin their own alpha
     * over a surface token instead of taking it whole (the media sheet, the OSD
     * plate). Normalised on frost, so frost renders byte-identical to the
     * shipped look while ink drives those alphas up to opaque and glass thins
     * them. Multiply, then clamp: `Math.min(1, hardAlpha * Theme.surfScale)`.
     */
    readonly property real surfScale: surfAlpha / 0.86

    /**
     * THE ACCENT VOCABULARY. Five canonical tokens, split by job: `mark` and
     * `markDim` are UI — the palette pipeline lifts the mark until it clears
     * 4.5:1 against the pill surface, so it is the only accent safe under
     * text and glyphs. `glow`, `glowDeep` and `glowInk` are light — filament,
     * ember and the string form Canvas needs — and carry no contrast promise.
     * Everything below them is a deprecated alias kept only until Task 3
     * rewires the consumers.
     *
     * The dynamic branch reads the split fields; until the cache is
     * regenerated (Task 9) Dyn.mark falls back to primary and Dyn.glow to
     * primary_container, so `glow` renders as the deep ember rather than the
     * filament for now. The static branch keeps each token's original curated
     * hex byte for byte.
     */
    readonly property color mark:     dyn ? Dyn.mark : "#e0762a"
    readonly property color markDim:  dyn ? Qt.darker(mark, 1.5) : "#8a6a48"
    readonly property color glow:     dyn ? Dyn.glow : "#ffb454"
    readonly property color glowDeep: dyn ? Dyn.primaryContainer : "#c2410c"
    /**
     * String-typed for Canvas: a color property serializes to #aarrggbb and
     * corrupts addColorStop/strokeStyle, so the raw palette hex goes through
     * untouched and no Qt.* math may be applied to it.
     */
    readonly property string glowInk: dyn ? Dyn.glow : "#ff9838"

    /**
     * DEPRECATED(night-glass): alias of mark, removed in Task 3.
     *
     * `onGlow` cannot be written as a plain binding any more: QML reads
     * `property T onFoo: expr` as a handler for `foo` once a member named
     * `foo` exists on the object, so declaring `glow` above silently turns
     * `onGlow: ...` into a script and leaves the token black. The indirection
     * through a nested object is the only way to keep the deprecated name
     * bindable; it dies with the alias. (Same mechanism, long blamed on
     * matugen, that empties Dyn.onPrimaryContainer.)
     */
    readonly property QtObject legacy: QtObject {
        id: legacyTokens
        readonly property color onGlow: Theme.dyn ? Theme.mark : "#ffb454"
    }
    readonly property alias onGlow: legacyTokens.onGlow

    /** DEPRECATED(night-glass): alias of mark, removed in Task 3. */
    readonly property color verm:     dyn ? Qt.darker(mark, 1.18) : "#e0762a"
    /** DEPRECATED(night-glass): alias of mark, removed in Task 3. */
    readonly property color vermLit:  dyn ? mark : "#ff9838"
    /** DEPRECATED(night-glass): alias of glowDeep, removed in Task 3. */
    readonly property color vermDeep: glowDeep
    readonly property color cream:    dyn ? Dyn.cream : "#d5dce6"
    readonly property color bright:   dyn ? Dyn.bright : "#f2f6fb"
    readonly property color dim:      dyn ? Dyn.dim : "#7d8797"
    readonly property color cardTop:  Qt.alpha(dyn ? Dyn.surfaceContainerHigh : "#161c28", surfAlpha)
    readonly property color cardBot:  Qt.alpha(dyn ? Dyn.surfaceContainerLow : "#10151f", surfAlpha)
    readonly property color border:   material === "ink" ? "transparent" : (dyn ? Dyn.outlineVariant : "#263042")
    readonly property color shadow:     Qt.rgba(0, 0, 0, 0.55)
    readonly property color tileBg:   Qt.alpha(dyn ? Dyn.surface : "#0e131c", surfAlpha)
    readonly property color subtle:   dyn ? Dyn.subtle : "#a4aebc"
    readonly property color faint:    dyn ? Dyn.faint : "#5d6570"
    readonly property color iconDim:  dyn ? Dyn.iconDim : "#b8c2cf"
    readonly property color hair:     Qt.alpha(cream, material === "glass" ? 0.22 : 0.13)
    readonly property color hairSoft: Qt.alpha(cream, material === "glass" ? 0.14 : 0.08)
    readonly property color sheen:    Qt.alpha(cream, material === "glass" ? 0.16 : 0.07)
    /** DEPRECATED(night-glass): alias of markDim, removed in Task 3. */
    readonly property color vermDim:   markDim
    /** DEPRECATED(night-glass): alias of mark, removed in Task 3. */
    readonly property color vermDimDeep: dyn ? Qt.darker(mark, 2.2) : "#55442e"
    /** DEPRECATED(night-glass): alias of glowDeep, removed in Task 3. */
    readonly property color vermBurn:  dyn ? Qt.darker(glowDeep, 1.1) : "#8a3a0a"
    readonly property color tickRest:  dyn ? Dyn.tickRest : "#aab6c6"
    readonly property color threadBg:  Qt.alpha(cream, 0.13)
    /** DEPRECATED(night-glass): alias of mark, removed in Task 3. */
    readonly property color flameCore: dyn ? Qt.lighter(mark, 1.03) : "#ffe2b8"
    /** DEPRECATED(night-glass): alias of mark, removed in Task 3. */
    readonly property color flameGlow: dyn ? mark : "#ffb454"

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render, so these take the raw
     * palette strings the canonical tokens are built from rather than the
     * canonical colors themselves — the string type is what keeps them off
     * `glowInk`, not a different source of truth. Task 3 moves the flame onto
     * glowInk/glowDeep, which is also where flameTip's rot gets fixed: it
     * currently renders EMPTY on a live palette, because Dyn.onPrimaryContainer
     * is unbindable by name (see the alias note above), and preserving that is
     * the only reason it still points there.
     */
    /** DEPRECATED(night-glass): alias of glowInk's source, removed in Task 3. */
    readonly property string flameInk:   dyn ? Dyn.mark : "#ff9838"
    /** DEPRECATED(night-glass): alias of glowDeep's source, removed in Task 3. */
    readonly property string flameEmber: dyn ? Dyn.primaryContainer : "#7a3410"
    /** DEPRECATED(night-glass): alias of glowDeep's source, removed in Task 3. */
    readonly property string flameBurn:  dyn ? Dyn.primaryContainer : "#8a3a0a"
    /** DEPRECATED(night-glass): no canonical equivalent, see above; removed in Task 3. */
    readonly property string flameTip:   dyn ? Dyn.onPrimaryContainer : "#ffcf8f"
    /** DEPRECATED(night-glass): alias of mark, removed in Task 3. */
    readonly property color todayWarm: dyn ? mark : "#ffcf8f"
    readonly property color ghost:     dyn ? Dyn.surfaceContainerHighest : "#2e3a50"
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.10)
    readonly property color creamMenu:     Qt.alpha(cream, 0.82)
    readonly property real shadowOpacity: 0.5
    /**
     * Snapshot of the system families, not a binding: Qt.fontFamilies() is not
     * notifiable, so a font dropped onto the pill re-registers through
     * refreshFonts() once its FontLoader is ready.
     */
    property var fontFamilies: Qt.fontFamilies()
    function refreshFonts() { fontFamilies = Qt.fontFamilies(); }
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
