pragma Singleton
import QtQuick
import Quickshell

/**
 * Lock palette, same split as the pill's Theme: the fixed hex is the identity
 * and the default, and with the dynamic-palette flag on the accent and text
 * family follow the wallpaper through Dyn. Each palette token is a single
 * ternary, so static mode renders byte-identical to the old fixed theme; the
 * derived tokens below simply layer alpha over those.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    readonly property color verm:   dyn ? Qt.darker(Dyn.primary, 1.18) : "#e0762a"
    readonly property color cream:  dyn ? Dyn.cream : "#d5dce6"
    readonly property color bright: dyn ? Dyn.bright : "#f2f6fb"
    readonly property color dim:    dyn ? Dyn.dim : "#7d8797"
    readonly property string font:  "Inter"

    /**
     * Sonoma frost. The capsule and the avatar are white glass floating over a
     * blurred desktop, so both the fill and the rim derive from `bright` at fixed
     * alphas instead of carrying their own warm tint. `bright` is already the
     * dyn/static ternary, so these stay a single source in both modes.
     */
    readonly property color fieldBg: Qt.alpha(bright, 0.16)
    readonly property color fieldBorder: Qt.alpha(bright, 0.25)
    /** Hairline rim for the avatar disc, same weight as the pill's `hair`. */
    readonly property color hair: Qt.alpha(cream, 0.13)
    readonly property color trackBg: dyn ? Qt.alpha(cream, 0.16) : Qt.rgba(240 / 255, 224 / 255, 215 / 255, 0.16)
    readonly property color error:  dyn ? Dyn.primary : "#ff9838"
}
