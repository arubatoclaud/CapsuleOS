pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * INPUT sub-surface: edits the pointer, keyboard and cursor settings that live
 * in the Hyprland Lua modules. Every row reads and writes through Store, which
 * owns input.lua/env.lua/autostart.lua, validates against Schema, rewrites the
 * right file and reloads Hyprland (or, for the cursor, applies live over
 * `hyprctl setcursor` with no reload) — so this surface carries no write
 * plumbing of its own. The theme list is scanned locally from the installed
 * icon themes that carry a `cursors/` folder, since that is a filesystem scan,
 * not a Schema-backed setting. Reached from the settings index; morphs back on
 * the back chevron.
 *
 * Resize on border (moved here from Windows in the settings restructure) is a
 * pointer-drag behavior, not a decoration knob, so it joins the Pointer group
 * even though it still writes decoration.lua's `resize_on_border` field
 * through Store's `deco` backend.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property var sensEntry: Schema.settings.sensitivity
    readonly property var accelEntry: Schema.settings.accelProfile
    readonly property var resizeOnBorderEntry: Schema.settings.resizeOnBorder
    readonly property var kbLayoutEntry: Schema.settings.kbLayout
    readonly property var rateEntry: Schema.settings.repeatRate
    readonly property var delayEntry: Schema.settings.repeatDelay
    readonly property var numlockEntry: Schema.settings.numlock
    readonly property var sizeEntry: Schema.settings.cursorSize

    property bool themeOpen: false
    property var cursorThemes: []

    /** Per-field values captured on each open; the ScrubValue undo glyphs revert to these. */
    property var base: ({})

    /** Curated layouts plus the current one when it is not already in the list, so an exotic layout still shows as-is and the row's cycle wraps back to the start. */
    readonly property var kbLayoutVals: {
        var opts = root.kbLayoutEntry.options.map(function (o) { return o.value; });
        var cur = Store.get("kbLayout");
        return opts.indexOf(cur) >= 0 ? opts : opts.concat([cur]);
    }

    onActiveChanged: {
        if (active) {
            seed();
            themeProc.running = true;
        } else {
            themeOpen = false;
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Resyncs Store from disk and snapshots the undo baseline for the scrub
     * rows. Values themselves come straight off Store.get, which already falls
     * back to Schema.settings[...].def when a field is missing from its file —
     * no hardcoded fallback constants here anymore.
     */
    function seed() {
        Store.reload();
        root.base = {
            sensitivity: Store.get("sensitivity"),
            repeatRate: Store.get("repeatRate"),
            repeatDelay: Store.get("repeatDelay"),
            cursorSize: Store.get("cursorSize")
        };
    }

    Process {
        id: themeProc
        command: ["sh", "-c", "{ printf '%s\\n' \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/share/icons; printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' '\\n' | sed 's#/*$#/icons#'; } | sort -u | while IFS= read -r d; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t/cursors\" ] && basename \"$t\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n").filter(function (l) { return l.trim().length > 0; });
                root.cursorThemes = lines;
            }
        }
    }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SettingsHeader {
            s: root.s
            glyph: "\uf245"
            title: "INPUT"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            SettingsGroupLabel { s: root.s; text: Schema.groupTitle("input", "pointer") }

            SettingsRow {
                id: sensRow
                surface: root
                settingId: "sensitivity"
                name: root.sensEntry.label
                sub: root.sensEntry.caption
                captionOnFocus: true
                icon: "mouse"
                ScrubValue {
                    id: sensScrub
                    s: root.s
                    value: Store.get("sensitivity")
                    openValue: root.base.sensitivity
                    from: root.sensEntry.from; to: root.sensEntry.to; step: root.sensEntry.step; decimals: 1
                    onEdited: v => Store.set("sensitivity", v)
                }
            }

            SettingsRow {
                id: accelRow
                surface: root
                settingId: "accelProfile"
                name: root.accelEntry.label
                sub: root.accelEntry.caption
                captionOnFocus: true
                icon: "bolt"
                SettingsSeg {
                    s: root.s
                    options: root.accelEntry.options
                    value: Store.get("accelProfile")
                    onPicked: (v) => Store.set("accelProfile", v)
                }
            }

            SettingsRow {
                id: resizeRow
                surface: root
                settingId: "resizeOnBorder"
                name: root.resizeOnBorderEntry.label
                sub: root.resizeOnBorderEntry.caption
                captionOnFocus: true
                icon: "app-window"
                last: true
                LinkToggle {
                    s: root.s
                    on: Store.get("resizeOnBorder")
                    onToggled: Store.set("resizeOnBorder", !Store.get("resizeOnBorder"))
                }
            }

            SettingsGroupLabel { s: root.s; text: Schema.groupTitle("input", "keyboard") }

            SettingsRow {
                id: layoutRow
                surface: root
                settingId: "kbLayout"
                navVals: root.kbLayoutVals
                name: root.kbLayoutEntry.label
                sub: root.kbLayoutEntry.caption
                captionOnFocus: true
                icon: "language"

                Rectangle {
                    width: layoutLbl.implicitWidth + 20 * root.s
                    height: 22 * root.s
                    radius: 9 * root.s
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.hairSoft

                    Text {
                        id: layoutLbl
                        anchors.centerIn: parent
                        text: Store.get("kbLayout")
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                    }
                }
            }

            SettingsRow {
                id: rateRow
                surface: root
                settingId: "repeatRate"
                name: root.rateEntry.label
                sub: root.rateEntry.caption
                captionOnFocus: true
                icon: "keyboard"
                ScrubValue {
                    id: rateScrub
                    s: root.s
                    value: Store.get("repeatRate")
                    openValue: root.base.repeatRate
                    from: root.rateEntry.from; to: root.rateEntry.to; step: root.rateEntry.step; unit: root.rateEntry.unit
                    onEdited: v => Store.set("repeatRate", v)
                }
            }

            SettingsRow {
                id: delayRow
                surface: root
                settingId: "repeatDelay"
                name: root.delayEntry.label
                sub: root.delayEntry.caption
                captionOnFocus: true
                icon: "stopwatch"
                ScrubValue {
                    id: delayScrub
                    s: root.s
                    value: Store.get("repeatDelay")
                    openValue: root.base.repeatDelay
                    from: root.delayEntry.from; to: root.delayEntry.to; step: root.delayEntry.step; unit: root.delayEntry.unit
                    onEdited: v => Store.set("repeatDelay", v)
                }
            }

            SettingsRow {
                id: numlockRow
                surface: root
                settingId: "numlock"
                name: root.numlockEntry.label
                sub: root.numlockEntry.caption
                captionOnFocus: true
                icon: "lock"
                last: true
                LinkToggle {
                    s: root.s
                    on: Store.get("numlock")
                    onToggled: Store.set("numlock", !Store.get("numlock"))
                }
            }

            SettingsGroupLabel { s: root.s; text: Schema.groupTitle("input", "cursor") }

            SettingsRow {
                id: sizeRow
                surface: root
                settingId: "cursorSize"
                name: root.sizeEntry.label
                sub: root.sizeEntry.caption
                captionOnFocus: true
                icon: "cursor"
                last: true
                ScrubValue {
                    id: sizeScrub
                    s: root.s
                    value: Store.get("cursorSize")
                    openValue: root.base.cursorSize
                    from: root.sizeEntry.from; to: root.sizeEntry.to; step: root.sizeEntry.step; unit: root.sizeEntry.unit
                    onEdited: v => Store.set("cursorSize", v)
                }
            }

            Item { width: 1; height: 8 * root.s }

            /**
             * DisplayPicker draws its own chip and dropdown, so the wrapper only
             * adds what keyboard navigation needs: the nav claim standing in for
             * the SettingsRow this line isn't, hover for the soul seam, and a
             * fall-through click that toggles the picker like the chip does.
             */
            Item {
                id: themeRow
                width: parent ? parent.width : 0
                height: themePick.implicitHeight

                SettingsNav {
                    item: themeRow
                    surface: root
                    navKind: "toggle"
                    navGet: () => root.themeOpen
                    navSet: (v) => root.themeOpen = v
                }

                HoverHandler {
                    onHoveredChanged: root.reportRowHover(themeRow, hovered)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.activateRow(themeRow)
                }

                DisplayPicker {
                    id: themePick
                    s: root.s
                    label: "Theme"
                    options: root.cursorThemes.map(function (t) { return { label: t, value: t }; })
                    value: Store.get("cursorTheme")
                    open: root.themeOpen
                    onRequestToggle: root.themeOpen = !root.themeOpen
                    onPicked: (v) => {
                        root.themeOpen = false;
                        Store.set("cursorTheme", v);
                    }
                }
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
