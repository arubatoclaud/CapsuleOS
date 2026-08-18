pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * WALLPAPER sub-surface: where the wallpapers come from and which screens the
 * random keybind repaints.
 *
 * The browser strip keeps its own folder edit in its header — that is where you
 * are standing when the folder turns out to be the wrong one — and this is the
 * same stored key from the settings side, so a path typed in either reads back
 * in both. `Random wallpaper` moved here from Appearance with it: it is the
 * Super+B target, which is a decision about wallpapers rather than about the
 * look of the shell.
 *
 * The surface id is `wallpaperSettings`, not `wallpaper`: that name already
 * belongs to the browser strip and to its ipc door.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property var dirEntry: Schema.settings.wallpaperDir
    readonly property var randomEntry: Schema.settings.randomScope

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "\uf03e"
            title: "WALLPAPER"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        /**
         * Empty means autodetect, so the field shows what the empty string
         * currently resolves to (`Walls.wpDir`) as its placeholder rather than
         * leaving the row blank. The claim is a `toggle` with a getter that is
         * always false: Return starts the edit, and nothing pretends this row
         * holds an on/off state.
         */
        SettingsRow {
            id: dirRow
            surface: root
            navKind: "toggle"
            navGet: () => false
            navSet: (v) => { if (v) dirEdit.begin(); }
            name: root.dirEntry.label
            sub: root.dirEntry.caption
            captionOnFocus: true
            icon: "image"

            SettingsTextEdit {
                id: dirEdit
                s: root.s
                value: Store.get("wallpaperDir")
                placeholder: Walls.wpDir
                onCommitted: (t) => Store.set("wallpaperDir", t)
            }
        }

        SettingsRow {
            id: randomRow
            surface: root
            settingId: "randomScope"
            name: root.randomEntry.label
            sub: root.randomEntry.caption
            captionOnFocus: true
            icon: "monitor"
            last: true

            SettingsSeg {
                s: root.s
                options: root.randomEntry.options
                value: Store.get("randomScope")
                onPicked: (v) => Store.set("randomScope", v)
            }
        }

        Text {
            topPadding: 12 * root.s
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            width: parent.width
            text: Walls.count + (Walls.count === 1 ? " wallpaper in " : " wallpapers in ") + Walls.wpDir
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WrapAnywhere
        }

        Item { width: 1; height: 10 * root.s }
    }
}
