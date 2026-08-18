pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * RECORDING sub-surface: the screen recorder's settings, given a home in the
 * settings tree.
 *
 * They have always existed — in a drawer that folds out of the recorder itself,
 * one tap from the record button — and that drawer stays exactly where it is,
 * because the frame rate is something you change while deciding what to
 * capture. What it stopped being is the only place they live and the only place
 * they are described. Both surfaces read their labels and option strips from
 * Schema and write through Store now, so neither can call a setting something
 * the other does not, and the index's search can find them.
 *
 * `Save to` is the one row with no control of its own: `ScreenRec.outDir` is
 * derived (empty folder = ~/Videos/Recordings), and the folder itself is chosen
 * by the native picker ScreenRec already runs for the recorder's own CHANGE
 * action, which writes `Flags.recordDir` when it returns.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property var dirEntry: Schema.settings.recordDir
    readonly property var fpsEntry: Schema.settings.recordFps
    readonly property var qualityEntry: Schema.settings.recordQuality
    readonly property var cursorEntry: Schema.settings.recordCursor
    readonly property var countdownEntry: Schema.settings.recordCountdown
    readonly property var micEntry: Schema.settings.recordMic
    readonly property var desktopEntry: Schema.settings.recordDesktop

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "\uf030"
            title: "RECORDING"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        /**
         * The claim is a `toggle` whose getter is always false, so Return (and a
         * right-arrow) opens the folder picker and nothing here pretends to hold
         * an on/off state. The picker is ScreenRec's, and its result lands on
         * `Flags.recordDir`, which `outDir` below is derived from.
         */
        SettingsRow {
            id: dirRow
            surface: root
            navKind: "toggle"
            navGet: () => false
            navSet: (v) => { if (v) ScreenRec.pickDir(); }
            name: root.dirEntry.label
            sub: ScreenRec.outDir
            icon: "download"
            last: true

            Text {
                text: "CHANGE"
                color: changeArea.containsMouse ? Theme.markGlow : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1 * root.s

                MouseArea {
                    id: changeArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ScreenRec.pickDir()
                }
            }
        }

        SettingsGroup { id: optionsGrp; s: root.s; hPad: 12 * root.s; title: Schema.groupTitle("recording", "options"); open: true

        SettingsRow {
            id: fpsRow
            surface: root
            settingId: "recordFps"
            name: root.fpsEntry.label
            sub: root.fpsEntry.caption
            captionOnFocus: true
            SettingsSeg {
                s: root.s
                options: root.fpsEntry.options
                value: Store.get("recordFps")
                onPicked: (v) => Store.set("recordFps", v)
            }
        }

        SettingsRow {
            id: qualityRow
            surface: root
            settingId: "recordQuality"
            name: root.qualityEntry.label
            sub: root.qualityEntry.caption
            captionOnFocus: true
            SettingsSeg {
                s: root.s
                options: root.qualityEntry.options
                value: Store.get("recordQuality")
                onPicked: (v) => Store.set("recordQuality", v)
            }
        }

        SettingsRow {
            id: cursorRow
            surface: root
            settingId: "recordCursor"
            name: root.cursorEntry.label
            sub: root.cursorEntry.caption
            captionOnFocus: true
            LinkToggle {
                s: root.s
                on: Store.get("recordCursor")
                onToggled: Store.set("recordCursor", !Store.get("recordCursor"))
            }
        }

        SettingsRow {
            id: countdownRow
            surface: root
            settingId: "recordCountdown"
            name: root.countdownEntry.label
            sub: root.countdownEntry.caption
            captionOnFocus: true
            last: true
            SettingsSeg {
                s: root.s
                options: root.countdownEntry.options
                value: ScreenRec.preroll
                onPicked: (v) => Store.set("recordCountdown", v)
            }
        }

        }

        SettingsGroup { id: audioGrp; s: root.s; hPad: 12 * root.s; title: Schema.groupTitle("recording", "audio"); open: true

        SettingsRow {
            id: micRow
            surface: root
            settingId: "recordMic"
            name: root.micEntry.label
            sub: root.micEntry.caption
            captionOnFocus: true
            LinkToggle {
                s: root.s
                on: Store.get("recordMic")
                onToggled: Store.set("recordMic", !Store.get("recordMic"))
            }
        }

        SettingsRow {
            id: desktopRow
            surface: root
            settingId: "recordDesktop"
            name: root.desktopEntry.label
            sub: root.desktopEntry.caption
            captionOnFocus: true
            last: true
            LinkToggle {
                s: root.s
                on: Store.get("recordDesktop")
                onToggled: Store.set("recordDesktop", !Store.get("recordDesktop"))
            }
        }

        }

        Item { width: 1; height: 10 * root.s }
    }
}
