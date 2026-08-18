pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Mini-segmented choice control. `options` is a list of `{ label, value }`; the
 * pill whose value equals `value` lights with a flame tint. Picking a pill emits
 * `picked(value)`; selection keys off the source value, never a child's effective
 * visibility. The host passes `s` for scale.
 */
Rectangle {
    id: seg

    property real s: 1
    property var options: []
    property var value
    signal picked(var value)

    /**
     * The option a two-step confirm is currently holding open, or `undefined`
     * when none is. It reads as vermilion rather than the flame tint of a
     * settled choice, so an armed pill is visibly a question and not an answer.
     * Only the danger segs (Session's Suspend) ever set it.
     */
    property var armedValue: undefined

    /**
     * When `flushLeft`, the control shifts left by the first option's text inset
     * so that text lines up with x=0 of where the control is placed, rather than
     * the pill edge sitting there.
     */
    property bool flushLeft: false

    readonly property real pad: 1
    readonly property real edgePad: seg.pad + 9 * seg.s

    x: seg.flushLeft ? -seg.edgePad : 0
    width: pills.implicitWidth + 2 * pad
    height: pills.implicitHeight + 2 * pad
    radius: Metrics.rCard * seg.s
    color: "transparent"

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 2 * seg.s

        Repeater {
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: seg.value === modelData.value
                readonly property bool armed: seg.armedValue !== undefined && seg.armedValue === modelData.value
                property bool hovered: false

                width: optLabel.implicitWidth + 18 * seg.s
                height: optLabel.implicitHeight + 12 * seg.s
                radius: Metrics.rCard * seg.s
                color: opt.armed ? Qt.alpha(Theme.markDeep, 0.42)
                    : (opt.current ? Qt.alpha(Theme.markGlow, 0.16) : (opt.hovered ? Theme.frameBg : "transparent"))
                border.width: opt.armed ? 1 : 0
                border.color: Qt.alpha(Theme.markLit, 0.7)
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    id: optLabel
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: (opt.current || opt.armed) ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * seg.s
                    font.weight: Font.Bold
                    font.letterSpacing: 0.3 * seg.s
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: opt.hovered = true
                    onExited: opt.hovered = false
                    onClicked: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
