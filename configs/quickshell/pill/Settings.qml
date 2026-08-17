pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * SETTINGS index: a short list of categories. Each row carries its kanji,
 * name and caption, and morphs the pill into that category's sub-surface.
 * Arrow keys move the focused row with the glowing seam and Return opens it.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: appearanceRow, kind: "nav", surface: "appearance" },
        { item: lookRow, kind: "nav", surface: "look" },
        { item: displayRow, kind: "nav", surface: "display" },
        { item: inputRow, kind: "nav", surface: "input" },
        { item: animationRow, kind: "nav", surface: "animation" },
        { item: keybindsRow, kind: "nav", surface: "keybinds" },
        { item: workspacesRow, kind: "nav", surface: "workspaces" },
        { item: idleRow, kind: "nav", surface: "idlelock" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "\uf013"
            title: "SETTINGS"
        }

        SettingsRow {
            id: appearanceRow
            surface: root
            icon: "sparkles"
            name: "Appearance"
            sub: "Clock, accent palette, scale"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearanceRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: lookRow
            surface: root
            icon: "app-window"
            name: "Look"
            sub: "Gaps, rounding, blur, opacity"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === lookRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: displayRow
            surface: root
            icon: "monitor"
            name: "Display"
            sub: "Resolution, refresh, scale"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === displayRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: inputRow
            surface: root
            icon: "mouse"
            name: "Input"
            sub: "Pointer, keyboard, cursor"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === inputRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: animationRow
            surface: root
            icon: "waves"
            name: "Animation"
            sub: "Speed, motion curve, enable"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === animationRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: keybindsRow
            surface: root
            icon: "keyboard"
            name: "Keybinds"
            sub: "Rebind, add, set commands"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === keybindsRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: workspacesRow
            surface: root
            icon: "layers"
            name: "Workspaces"
            sub: "Special spaces and their keys"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === workspacesRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: idleRow
            surface: root
            icon: "lock"
            name: "Idle / Lock"
            sub: "Auto-lock, screen off, suspend"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === idleRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }
    }
}
