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
     * follows, and nothing multiplies on top of it at the window level.
     */
    readonly property string material: Flags.material

    /**
     * GLASS TRACKS THE TERMINAL BACKGROUND. `background-opacity` from the
     * ghostty config times Hyprland's `active_opacity` is the exact alpha a
     * focused window's background composites at, so binding glass to that
     * product makes the pill read as the same pane the windows under it are
     * made of, and one control moves both. Frost and ink keep fixed alphas of
     * their own: frost is the palette's contract value (see `surfAlpha`), ink
     * is opaque by definition.
     *
     * Both halves are BINDINGS onto Store, not `get()` snapshots, so a write
     * from Windows › Transparency — or a hand edit of either file that Store
     * re-reads — repaints the pill straight away. Store falls each half back to
     * its Schema default when the file will not parse, so an unreadable config
     * yields the shipped look rather than a pill that vanishes.
     *
     * This replaced a standalone `pillOpacity` flag that multiplied on top of a
     * fixed 0.62 at the two Pill.qml render sites. Two independent controls over
     * one composited alpha is what let the pill's blur switch off silently:
     * their product could fall under the `pill-blur` layer_rule's `ignore_alpha`
     * with no setting anywhere admitting that blur had changed.
     */
    readonly property real glassAlpha: Store.termBgOpacity * Store.activeOpacity
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
     * THE alpha every surface token composites at, and the only one: there is
     * no second factor applied downstream of it.
     *
     * Translucent surfaces composite the wallpaper through the pill, and on a
     * bright wallpaper that eats the accent's contrast. The palette guarantees
     * the mark 4.5:1 against the pill card as it composites at SURF_ALPHA =
     * 0.86, which frost meets exactly and ink beats. Glass used to be floored
     * back to 0.85 on `Dyn.brightSurface` to buy that same margin on a bright
     * wallpaper; that floor is gone, because glass is no longer a constant the
     * renderer picked but the user's own window-background opacity, and
     * overriding it would mean the pill quietly refusing the transparency the
     * Windows › Transparency scrubs say it has. On glass the 4.5:1 guarantee is
     * therefore user-governed: thinner glass trades legibility for translucency
     * by the user's explicit instruction, the same trade wallcolors.py's
     * SURF_ALPHA comment already hands to the renderer.
     */
    readonly property real surfAlpha: material === "glass" ? glassAlpha : material === "ink" ? 1.0 : 0.86

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
     * The block below them is derived accents promoted from Task 3's
     * consumer sweep (see that block's own comment); the fourteen washi/Ame
     * -era aliases (verm*, onGlow, flame*, todayWarm) are gone.
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
     * untouched and no Qt.* math may be applied to it. In static mode, glowInk
     * and glow are independently curated; dynamically both are Dyn.glow.
     */
    readonly property string glowInk: dyn ? Dyn.glow : "#ff9838"

    /**
     * Night Glass derived accents, promoted out of Task 3's consumer sweep:
     * each carries a static-mode hex distinct from any canonical token's own,
     * so inlining the dyn expression at every call site would have silently
     * dropped that curated value. Comments record what each replaces.
     */
    readonly property color markDeep:     dyn ? Qt.darker(mark, 1.18) : "#e0762a"
    readonly property color markLit:      dyn ? mark : "#ff9838"
    readonly property color markDimDeep:  dyn ? Qt.darker(mark, 2.2) : "#55442e"
    readonly property color markLift:     dyn ? Qt.lighter(mark, 1.03) : "#ffe2b8"
    readonly property color markGlow:     dyn ? mark : "#ffb454"
    readonly property color markWarm:     dyn ? mark : "#ffcf8f"
    readonly property color glowBurn:     dyn ? Qt.darker(glowDeep, 1.1) : "#8a3a0a"
    /**
     * String-typed like glowInk, for the same Canvas addColorStop reason:
     * these feed the flame gradient's ink/ember/coal stops directly.
     */
    readonly property string markInk:     dyn ? Dyn.mark : "#ff9838"
    readonly property string glowEmber:   dyn ? Dyn.primaryContainer : "#7a3410"
    readonly property string glowCoal:    dyn ? Dyn.primaryContainer : "#8a3a0a"
    /**
     * glowTip replaces flameTip, which read Dyn.onPrimaryContainer and so
     * always rendered empty: `onPrimaryContainer` sits next to
     * `primaryContainer` on Dyn, and QML reads `property T onFoo: expr` as a
     * handler for `foo` whenever a member named `foo` exists on the object,
     * so the binding was discarded from the day it was written (same trap
     * `onGlow` needed the nested-QtObject workaround for, now gone). glowTip
     * is the intended visible color instead: a hot tip lifted off glow. It is
     * color-typed, not string, because Qt.lighter needs a real color to work
     * on and its only consumer (Ame.qml's flame stroke) assigns it directly,
     * the same pattern markLit and markDeep already use there safely.
     */
    readonly property color glowTip:      dyn ? Qt.lighter(glow, 1.25) : "#ffcf8f"

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
    readonly property color tickRest:  dyn ? Dyn.tickRest : "#aab6c6"
    readonly property color threadBg:  Qt.alpha(cream, 0.13)
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
