import QtQuick
import "Singletons"

/**
 * Horizontal capture-level fader for the recorder's audio rows: a thin matte
 * track with a flame fill and a flat tick marker at the value, no knob. Mirrors
 * the mixer VFader look and contract (drag plus `step` for scroll-wheel and
 * arrow keys, 5% per notch) so the same focus and stepping logic drives it.
 * The host owns focus and feeds `focused`; `on` saturates the fill, off dims
 * it. Value is 0..1. A right-aligned percent readout trails the track.
 */
Item {
    id: root

    property real s: 1
    property real value: 0.5
    property bool focused: false
    property bool on: true

    signal moved(real v)
    signal committed(real v)
    signal focusRequested()

    implicitHeight: 16 * s

    /**
     * Nudge the value by a signed percentage (e.g. +5 / -5), clamped to 0..100%,
     * emitting `moved` and `committed` so the captured level updates on each step.
     */
    function step(deltaPct) {
        const v = Math.max(0, Math.min(1, root.value + deltaPct / 100));
        root.moved(v);
        root.committed(v);
    }

    readonly property real clamped: Math.max(0, Math.min(1, value))

    /**
     * Animated copy of `clamped` that the fill and tick draw from. Animating
     * this fraction (instead of pixel width/x) keeps both inside the track
     * while the surface's open morph is still resizing the track itself.
     */
    property real vis: clamped
    Behavior on vis { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast } }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: pct.left
        anchors.rightMargin: 11 * root.s
        anchors.verticalCenter: parent.verticalCenter
        height: 3 * root.s
        radius: height / 2
        color: Theme.threadBg

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, parent.width) * root.vis
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.on ? Theme.glowBurn : Theme.markDimDeep }
                GradientStop { position: 1.0; color: root.on ? Theme.markLit : Theme.markDim }
            }
        }

        Rectangle {
            id: tick
            x: Math.max(0, Math.min(track.width - width, track.width * root.vis - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 2.5 * root.s
            height: 11 * root.s
            radius: 2 * root.s
            color: Theme.tickRest
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -8 * root.s
            preventStealing: true
            enabled: root.on
            function setFromX(mx) {
                const v = Math.max(0, Math.min(1, (mx + 8 * root.s) / track.width));
                root.moved(v);
            }
            onPressed: (e) => { root.focusRequested(); setFromX(e.x); }
            onPositionChanged: (e) => { if (pressed) setFromX(e.x); }
            onReleased: root.committed(root.value)
        }
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32 * root.s
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.clamped * 100) + "%"
        color: root.focused ? Theme.cream : Theme.subtle
        font.family: Theme.font
        font.pixelSize: Metrics.tBody * root.s
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }
}
