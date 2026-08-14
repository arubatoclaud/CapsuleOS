pragma Singleton
import QtQuick
import Quickshell

Singleton {
    /**
     * Motion character, one knob over every duration and the morph curve.
     * calm: Apple standard curve ~300ms; spring: overshoot settle; glide:
     * cinematic. `mult` still folds reduce-motion on top, and the property
     * names below never change, so no consumer has to know which character is
     * live. `heat` is the power-tile hold and stays fixed — it is a dwell time,
     * not an animation.
     */
    readonly property string character: Flags.motion
    readonly property real mult: Flags.reduceMotion ? 0.4 : 1
    readonly property real cMult: character === "glide" ? 1.25 : character === "spring" ? 1.0 : 0.78
    readonly property int fast:       Math.round(140 * cMult * mult)
    readonly property int standard:   Math.round(300 * cMult * mult)
    readonly property int morph:      Math.round(420 * cMult * mult)
    readonly property int shapeshift: Math.round(820 * cMult * mult)
    readonly property int glide:      Math.round(260 * cMult * mult)
    readonly property int heat:       Math.round(1100 * mult)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline

    /**
     * Liquid morph curve, fed to easeMorph (BezierSpline). Calm is
     * cubic-bezier(0.32, 0.72, 0, 1), a front-loaded chase with a long settle
     * tail; spring overshoots past 1 and drops back; glide eases in slowly
     * before the same hard settle.
     */
    readonly property var morphCurve:
        character === "spring" ? [0.34, 1.56, 0.64, 1, 1, 1]
        : character === "glide" ? [0.45, 0.05, 0.15, 1, 1, 1]
        : [0.32, 0.72, 0, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13

    /** Looping scan/pairing breath pulse. */
    readonly property int pulse: Math.round(420 * mult)
}
