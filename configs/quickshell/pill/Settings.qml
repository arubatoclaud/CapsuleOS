pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * SETTINGS index: the list of categories, drawn straight from `Schema.pages`.
 *
 * This used to be one hand-copied block per category — icon, name, caption and
 * a chevron, eight times over — with the same strings spelled a second time in
 * Schema for the search to read. The Repeater below is the whole index now: a
 * category is an entry in `Schema.pages` plus its surface, and its title and
 * caption can only ever read one way because there is only one copy of them.
 *
 * Each row still claims its own nav slot through `navTarget` (the page id,
 * which is also the surface id the settings stack routes on), so arrow keys
 * move the focused row with the glowing seam and Return opens it exactly as
 * before.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

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

        Repeater {
            model: Schema.pages

            SettingsRow {
                id: pageRow
                required property var modelData
                required property int index

                surface: root
                navTarget: pageRow.modelData.id
                icon: pageRow.modelData.icon
                name: pageRow.modelData.title
                sub: pageRow.modelData.caption
                last: pageRow.index === Schema.pages.length - 1

                GlyphIcon {
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "chevron-right"
                    color: root.focusRowItem === pageRow ? Theme.cream : Theme.iconDim
                    stroke: 2.2
                }
            }
        }
    }
}
