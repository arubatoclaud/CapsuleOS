pragma Singleton
import QtQuick
import Quickshell

/**
 * Radius, type, hairline and icon tokens for the pill shell.
 * Source: the "Night Glass" designer memo, 2026-08 PillOS audit artifact §05.
 * Radius family (call 5): 7/9/13/18/22+999, one corner language shell-wide.
 * Type scale (call 7): six fixed steps, no ad hoc font.pixelSize elsewhere.
 */
Singleton {
    // Radius family. rSmall/rTile move here from Motion.qml unchanged.
    readonly property real rSmall:     7
    readonly property real rCard:      9
    readonly property real rTile:      13
    readonly property real rPill:      18
    readonly property real rPillOpen:  22
    readonly property real rFull:      999

    // Type scale, six steps.
    readonly property real tCaption:   9
    readonly property real tBody:      10.5
    readonly property real tLabel:     11.5
    readonly property real tTitle:     13
    readonly property real tHead:      16
    readonly property real tDisplay:   18

    /**
     * Hairline width. Metrics has no ambient `s` (Motion/Theme are consumed
     * by widgets that carry their own local scale), so hairW takes the
     * caller's scale as a parameter rather than reading a singleton-wide one.
     * hairPx is the unscaled reference value for call sites that want it raw.
     */
    readonly property real hairPx: 1
    function hairW(s) { return Math.max(1, Math.round(1 * s)) }

    // Hover-row icon series (Task 6 consumers): one size/stroke pair.
    readonly property real iconRow:    16
    readonly property real iconStroke: 1.8
}
