pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Collapsible settings group: a tappable header (the group label plus a
 * chevron) over a body of rows that animates between zero and its content
 * height, so a long tab shows only the group headers until one is opened.
 * `open` is the initial state; tapping the header toggles it. Promoted from
 * Look.qml's local `Group`; visuals unchanged. `s` carries scale since this
 * lives outside any surface.
 */
Column {
    id: grp

    property real s: 1
    property string title: ""
    property bool open: false
    /**
     * Horizontal inset for the HEADER only — the label and the chevron. Pages
     * differ in where their padding lives: Look and Input inset a whole column
     * of rows, so their groups sit at 0, while Animation's rows are full width
     * and carry their own padding, so its group header has to be pushed in to
     * line up with the standalone labels above it. The body is never inset, so
     * a group's rows always align with the page's ungrouped ones.
     */
    property real hPad: 0
    default property alias rows: body.data

    width: parent ? parent.width : 0
    spacing: 0

    Item {
        width: parent.width
        height: gl.implicitHeight

        SettingsGroupLabel { id: gl; s: grp.s; leftPadding: grp.hPad; text: grp.title }

        GlyphIcon {
            anchors.right: parent.right
            anchors.rightMargin: grp.hPad
            anchors.verticalCenter: gl.verticalCenter
            width: Metrics.iconRow * grp.s
            height: Metrics.iconRow * grp.s
            name: "chevron-down"
            color: Theme.faint
            stroke: Metrics.iconStroke
            rotation: grp.open ? 0 : -90
            Behavior on rotation { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: grp.open = !grp.open
        }
    }

    /**
     * Going invisible once the fold has finished closing is what drops the
     * group's rows out of keyboard navigation: `visible` composes down the
     * parent chain, so a SettingsRow inside a shut group stops claiming its nav
     * slot without the page mirroring `open` in a registry. Tied to the
     * animated height rather than `open` so the collapse still plays in full.
     */
    Item {
        width: parent.width
        height: grp.open ? body.implicitHeight : 0
        visible: height > 0
        clip: true
        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

        Column {
            id: body
            width: parent.width
        }
    }
}
