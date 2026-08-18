pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * IDLE / LOCK sub-surface: the three idle timeouts that drive hypridle, each
 * held in minutes (0 = off). Auto-lock runs the lock script, screen-off blanks
 * the display through DPMS, and suspend sleeps the machine. Every row reads and
 * writes through Store, which regenerates the whole hypridle.conf from the
 * current values and restarts hypridle, so the change lands without a hand edit
 * and this surface carries no write plumbing of its own. Labels, captions and
 * the option strips come from Schema, so a rename is an edit there, not here.
 * Keep-awake in the mixer already inhibits the Wayland idle notification, which
 * pauses every listener while it is on, so this surface never touches that
 * wiring. Reached from the settings index and morphs back to it on an empty
 * click or the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    readonly property var lockEntry: Schema.settings.idleLockMin
    readonly property var screenEntry: Schema.settings.idleScreenOffMin
    readonly property var suspendEntry: Schema.settings.idleSuspendMin

    rows: [
        { item: lockRow, kind: "seg", vals: root.lockEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("idleLockMin"); }, set: function (v) { Store.set("idleLockMin", v); } },
        { item: screenRow, kind: "seg", vals: root.screenEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("idleScreenOffMin"); }, set: function (v) { Store.set("idleScreenOffMin", v); } },
        { item: suspendRow, kind: "seg", vals: root.suspendEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("idleSuspendMin"); }, set: function (v) { Store.set("idleSuspendMin", v); } }
    ]

    /**
     * One idle row: name and caption on their own full-width line with the
     * segmented control stacked below, so a six-option strip never squeezes the
     * caption into a narrow wrapping column. Hover lights the row and feeds the
     * soul seam, matching the rest of the settings rows.
     */
    component IdleRow: Item {
        id: irow
        property string name: ""
        property string caption: ""
        property bool last: false
        default property alias seg: segSlot.data
        readonly property real s: root.s

        width: parent ? parent.width : 0
        height: col.implicitHeight + 22 * irow.s

        HoverHandler {
            id: ih
            onHoveredChanged: root.reportRowHover(irow, hovered)
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3 * irow.s
            anchors.bottomMargin: 3 * irow.s
            radius: 9 * irow.s
            color: (ih.hovered || root.focusRowItem === irow) ? Theme.frameBg : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * irow.s
            anchors.rightMargin: 12 * irow.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * irow.s

            Text {
                text: irow.name
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * irow.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: irow.caption.length > 0
                text: irow.caption
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * irow.s
            }
            Item { width: 1; height: 7 * irow.s }
            Item {
                id: segSlot
                width: childrenRect.width
                height: childrenRect.height
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
            visible: !irow.last
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "\uf023"
            title: "IDLE / LOCK"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        IdleRow {
            id: lockRow
            name: root.lockEntry.label
            caption: root.lockEntry.caption

            SettingsSeg {
                s: root.s
                flushLeft: true
                options: root.lockEntry.options
                value: Store.get("idleLockMin")
                onPicked: (v) => Store.set("idleLockMin", v)
            }
        }

        IdleRow {
            id: screenRow
            name: root.screenEntry.label
            caption: root.screenEntry.caption

            SettingsSeg {
                s: root.s
                flushLeft: true
                options: root.screenEntry.options
                value: Store.get("idleScreenOffMin")
                onPicked: (v) => Store.set("idleScreenOffMin", v)
            }
        }

        IdleRow {
            id: suspendRow
            name: root.suspendEntry.label
            caption: root.suspendEntry.caption
            last: true

            SettingsSeg {
                s: root.s
                flushLeft: true
                options: root.suspendEntry.options
                value: Store.get("idleSuspendMin")
                onPicked: (v) => Store.set("idleSuspendMin", v)
            }
        }

        Text {
            topPadding: 12 * root.s
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            width: parent.width
            text: "Keep-awake (in the mixer) pauses all of this while it is on."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 10 * root.s }
    }
}
