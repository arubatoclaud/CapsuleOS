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

        SettingsRow {
            id: lockRow
            surface: root
            settingId: "idleLockMin"
            name: root.lockEntry.label
            sub: root.lockEntry.caption
            captionOnFocus: true

            SettingsSeg {
                s: root.s
                options: root.lockEntry.options
                value: Store.get("idleLockMin")
                onPicked: (v) => Store.set("idleLockMin", v)
            }
        }

        SettingsRow {
            id: screenRow
            surface: root
            settingId: "idleScreenOffMin"
            name: root.screenEntry.label
            sub: root.screenEntry.caption
            captionOnFocus: true

            SettingsSeg {
                s: root.s
                options: root.screenEntry.options
                value: Store.get("idleScreenOffMin")
                onPicked: (v) => Store.set("idleScreenOffMin", v)
            }
        }

        SettingsRow {
            id: suspendRow
            surface: root
            settingId: "idleSuspendMin"
            name: root.suspendEntry.label
            sub: root.suspendEntry.caption
            captionOnFocus: true
            last: true

            SettingsSeg {
                s: root.s
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
