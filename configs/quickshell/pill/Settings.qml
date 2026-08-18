pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * SETTINGS index: the list of categories, drawn straight from `Schema.pages`,
 * plus a search field that reaches past the category list into every entry in
 * `Schema.settings`. Typing folds the category list out of view and shows a
 * plain, non-virtualized list of matches instead — Schema carries under a
 * hundred entries, so a full rebuild on every keystroke costs nothing.
 *
 * Both lists are ordinary `SettingsRow`s claiming a nav slot the usual way, so
 * hiding one is exactly a SettingsGroup's fold: `height` collapses to zero and
 * `visible` follows it, which drops every row's SettingsNav claim down the
 * parent chain without either list telling the registry so a second time.
 * `results` is a fresh array every keystroke on purpose — it drives a Repeater
 * that fully rebuilds rather than a model mutated in place under registered
 * rows.
 *
 * A result row is a plain nav row like a category row: `navTarget` is the
 * page id, so Return or a click runs through the same `requestSurface` call a
 * category row already made. Nothing here reads or binds on the pill's
 * settings stack — activation only ever emits `requestSurface`, imperatively.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    property string query: ""

    /**
     * A page's title for the "Label — Page" line. Falls back to a capitalized
     * page id for the couple of settings (the mixer's) that live on a page
     * outside the index, so a hit there still reads as a place, not a blank.
     */
    function pageTitleFor(pageId) {
        for (var i = 0; i < Schema.pages.length; i++)
            if (Schema.pages[i].id === pageId)
                return Schema.pages[i].title;
        return pageId.length > 0 ? pageId.charAt(0).toUpperCase() + pageId.slice(1) : "";
    }

    function pageIconFor(pageId) {
        for (var i = 0; i < Schema.pages.length; i++)
            if (Schema.pages[i].id === pageId)
                return Schema.pages[i].icon;
        return "";
    }

    /**
     * Every Schema entry whose label, caption, group title or page title contains
     * the live query, case-insensitively. The group title is in the haystack
     * because a feature's name is often the group's, not the row's: night light is
     * four rows called Mode, Warmth, Turns on and Turns off, and without their
     * group they were unfindable by the only name the user knows them by.
     * `control: "custom"` rows with no Store key of their own (the monitor card,
     * the keybind editor and the like) are still plain entries here — a hit just
     * opens the page a click on it always opened.
     */
    readonly property var results: {
        var q = root.query.trim().toLowerCase();
        if (q.length === 0)
            return [];
        var out = [];
        var ids = Object.keys(Schema.settings);
        for (var i = 0; i < ids.length; i++) {
            var e = Schema.settings[ids[i]];
            var title = root.pageTitleFor(e.page);
            var hay = (e.label + " " + e.caption + " " + Schema.groupTitle(e.page, e.group)
                + " " + title).toLowerCase();
            if (hay.indexOf(q) < 0)
                continue;
            out.push({
                id: ids[i],
                label: e.label,
                pageId: e.page,
                pageTitle: title,
                icon: root.pageIconFor(e.page)
            });
        }
        out.sort(function (a, b) { return a.label.toLowerCase() < b.label.toLowerCase() ? -1 : 1; });
        return out;
    }

    /**
     * Focus the field on open and drop it, with the query, on close — the
     * same lifecycle FontPicker's own search uses. A `Connections` rather
     * than `onActiveChanged` on `root` directly: `SettingsSurface` already
     * carries its own `onActiveChanged` that clears `focusRowItem`/`kbIndex`,
     * and a second direct handler here would replace that one instead of
     * running beside it.
     */
    Connections {
        target: root
        function onActiveChanged() {
            if (root.active) {
                Qt.callLater(searchField.forceActiveFocus);
            } else {
                root.query = "";
                searchField.text = "";
            }
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
            glyph: "\uf013"
            title: "SETTINGS"
        }

        Item { width: 1; height: 10 * root.s }

        Item {
            width: parent.width
            height: 28 * root.s

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                width: Flags.showGlyphs ? implicitWidth : 0
                text: "\uf002"
                color: Theme.dim
                font.family: Theme.fontIcon
                font.weight: Font.Medium
                font.pixelSize: 15 * root.s
            }

            TextField {
                id: searchField
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 4 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                background: null
                padding: 0
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                placeholderText: "search settings"
                placeholderTextColor: Theme.faint
                selectByMouse: true
                selectionColor: Theme.markDeep
                onTextChanged: root.query = text
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) {
                        root.kbMove(1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.kbMove(-1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.kbActivate();
                        e.accepted = true;
                    }
                }
            }

            Rectangle {
                anchors.left: searchField.left
                anchors.right: searchField.right
                anchors.top: searchField.bottom
                anchors.topMargin: 3 * root.s
                height: 1
                color: Theme.faint
                opacity: searchField.activeFocus ? 0.7 : 0.18
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }

        Item { width: 1; height: 6 * root.s }

        /**
         * The category list. Folds to zero height and `visible: false` while a
         * query is live, which — like a collapsed SettingsGroup — drops every
         * row's SettingsNav claim without the page saying so a second time.
         */
        Item {
            id: categoryWrap
            width: parent.width
            height: root.query.length === 0 ? categoryCol.implicitHeight : 0
            visible: height > 0
            clip: true

            Column {
                id: categoryCol
                width: parent.width
                spacing: 0

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

        /**
         * Search results: one plain nav row per Schema hit, never a mutation
         * of a category row, so the registry sees ordinary register/
         * unregister traffic as the query changes.
         */
        Item {
            id: resultsWrap
            width: parent.width
            height: root.query.length > 0 ? resultsCol.implicitHeight : 0
            visible: height > 0
            clip: true

            Column {
                id: resultsCol
                width: parent.width
                spacing: 0

                Repeater {
                    model: root.results

                    SettingsRow {
                        id: resultRow
                        required property var modelData
                        required property int index

                        surface: root
                        navTarget: resultRow.modelData.pageId
                        icon: resultRow.modelData.icon
                        name: resultRow.modelData.label + " — " + resultRow.modelData.pageTitle
                        last: resultRow.index === root.results.length - 1

                        GlyphIcon {
                            width: 16 * root.s
                            height: 16 * root.s
                            name: "chevron-right"
                            color: root.focusRowItem === resultRow ? Theme.cream : Theme.iconDim
                            stroke: 2.2
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.query.length > 0 && root.results.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 20 * root.s
                    bottomPadding: 20 * root.s
                    text: "No matching settings"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Medium
                }
            }
        }
    }
}
