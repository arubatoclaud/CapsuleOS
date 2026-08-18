pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

/**
 * APPEARANCE sub-surface: the clock format and seconds, the palette mode
 * (static flame, dynamic per-wallpaper, or a manually chosen hue), the UI scale
 * and a reduce-motion switch. Reached from the settings index and morphs back to it on an empty click
 * or the back chevron.
 *
 * Every row but the manual-palette editor reads and writes through Store,
 * which validates against Schema and assigns the matching Flags key — so this
 * surface carries no write plumbing of its own beyond the palette rows below.
 *
 * `Palette` is the deliberate exception: choosing Manual or Dynamic also has
 * to run the wallcolors.py repaint process (rebuilding the whole rice colour
 * set and reloading Hyprland and the terminal), which is not a Schema field
 * Store can route. `applyMode` sets the `paletteMode` flag through Store and
 * then drives the process locally — the same shape as Look.qml's
 * `setPillBlur`/`setMaterial`. The manual hue strip, tone seg and hex field
 * write `manualHue`/`manualSat`/`manualDark` straight to Flags — Schema marks
 * them `control: "custom"` and they stay off Store exactly as before, each
 * edit calling `applyManual()` to debounce the same repaint.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    readonly property var timeEntry: Schema.settings.time12h
    readonly property var secEntry: Schema.settings.clockSeconds
    readonly property var vizEntry: Schema.settings.musicViz
    readonly property var paletteEntry: Schema.settings.paletteMode
    readonly property var randomEntry: Schema.settings.randomScope
    readonly property var scaleEntry: Schema.settings.uiScale
    readonly property var motionEntry: Schema.settings.reduceMotion
    readonly property var fontEntry: Schema.settings.uiFont

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: {
        var c = accentColor;
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function applyManual() {
        hueArg = String(Math.round(Flags.manualHue));
        modeArg = Flags.manualDark ? "dark" : "light";
        satArg = String(Flags.manualSat);
        applyTimer.restart();
    }

    function applyMode(v) {
        Store.set("paletteMode", v);
        if (v === "manual")
            applyManual();
        else if (v === "dynamic")
            dynamicProc.running = true;
    }

    Timer {
        id: applyTimer
        interval: 260
        repeat: false
        onTriggered: paletteProc.running = true
    }

    Process {
        id: paletteProc
        command: ["sh", "-c",
            "python3 \"$HOME/.config/hypr/scripts/wallcolors.py\" --hue \"$1\" \"$2\" \"$3\" && hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    Process {
        id: dynamicProc
        command: ["sh", "-c",
            "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/pillos-wallpaper\"; pic=$(cat \"$f\" 2>/dev/null); case \"$pic\" in *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv]) pic=\"${XDG_STATE_HOME:-$HOME/.local/state}/pillos-wallpaper-still.png\";; esac; [ -f \"$pic\" ] && python3 \"$HOME/.config/hypr/scripts/wallcolors.py\" \"$pic\" >/dev/null 2>&1; hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true"]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Store.get("paletteMode") === "manual")
                root.applyManual();
        }
        function onManualSatChanged() {
            if (Store.get("paletteMode") === "manual")
                root.applyManual();
        }
    }

    rows: [
        { item: timeRow, kind: "seg", vals: root.timeEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("time12h"); }, set: function (v) { Store.set("time12h", v); } },
        { item: secRow, kind: "toggle", get: function () { return Store.get("clockSeconds"); }, set: function (v) { Store.set("clockSeconds", v); } },
        { item: vizRow, kind: "toggle", get: function () { return Store.get("musicViz"); }, set: function (v) { Store.set("musicViz", v); } },
        { item: paletteRow, kind: "seg", vals: root.paletteEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("paletteMode"); }, set: function (v) { root.applyMode(v); } },
        { item: randomRow, kind: "seg", vals: root.randomEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("randomScope"); }, set: function (v) { Store.set("randomScope", v); } },
        { item: scaleRow, kind: "seg", vals: root.scaleEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("uiScale"); }, set: function (v) { Store.set("uiScale", v); } },
        { item: motionRow, kind: "toggle", get: function () { return Store.get("reduceMotion"); }, set: function (v) { Store.set("reduceMotion", v); } },
        { item: fontRow, kind: "nav", surface: "fontpicker" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "\uf042"
            title: "APPEARANCE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: timeRow
            surface: root
            name: root.timeEntry.label
            icon: "clock"

            SettingsSeg {
                s: root.s
                options: root.timeEntry.options
                value: Store.get("time12h")
                onPicked: (v) => Store.set("time12h", v)
            }
        }

        SettingsRow {
            id: secRow
            surface: root
            name: root.secEntry.label
            icon: "stopwatch"

            LinkToggle {
                s: root.s
                on: Store.get("clockSeconds")
                onToggled: Store.set("clockSeconds", !Store.get("clockSeconds"))
            }
        }

        SettingsRow {
            id: vizRow
            surface: root
            name: root.vizEntry.label
            icon: "music"

            LinkToggle {
                s: root.s
                on: Store.get("musicViz")
                onToggled: Store.set("musicViz", !Store.get("musicViz"))
            }
        }

        SettingsRow {
            id: paletteRow
            surface: root
            name: root.paletteEntry.label
            icon: "palette"

            SettingsSeg {
                s: root.s
                options: root.paletteEntry.options
                value: Store.get("paletteMode")
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Manual hue editor, folded shut unless the palette is on Manual. Holds a
         * rainbow strip with a draggable thumb, then a single line pairing a live
         * accent swatch and its hex caption with the dark/light choice, and a hex
         * input that drives both hue and saturation. The strip is mouse-driven and
         * stays out of the keyboard row registry.
         */
        Item {
            id: manualSection
            width: parent.width
            height: Store.get("paletteMode") === "manual" ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 14 * root.s

                    Rectangle {
                        id: hueStrip
                        anchors.fill: parent
                        radius: 7 * root.s
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                        }

                        Rectangle {
                            id: hueThumb
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Flags.manualHue / 359) * (hueStrip.width - width)
                            color: root.accentColor
                            border.width: 2.5 * root.s
                            border.color: Theme.cream
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setHue(mx) {
                                if (Flags.manualSat < 0.05)
                                    Flags.manualSat = 0.5;
                                Flags.manualHue = Math.round(Math.max(0, Math.min(1, mx / hueStrip.width)) * 359);
                            }
                            onPressed: (mouse) => setHue(mouse.x)
                            onPositionChanged: (mouse) => setHue(mouse.x)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, toneSeg.implicitHeight)

                    Rectangle {
                        id: accentSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColor
                        border.width: 1
                        border.color: Theme.border
                    }

                    Column {
                        anchors.left: accentSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.right: toneSeg.left
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            text: "Accent hue"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.currentHex + " · " + (Flags.manualDark ? "dark" : "light")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: ({ "tnum": 1 })
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    SettingsSeg {
                        id: toneSeg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.manualDark
                        onPicked: (v) => { Flags.manualDark = v; root.applyManual(); }
                    }
                }

                Item {
                    width: parent.width
                    height: 30 * root.s

                    Text {
                        id: hexHint
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: hexField
                        anchors.left: hexHint.right
                        anchors.leftMargin: 6 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: ({ "tnum": 1 })
                        placeholderText: root.currentHex
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 7

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var raw = text.trim();
                            var clean = raw.charAt(0) === "#" ? raw.slice(1) : raw;
                            if (/^[0-9a-fA-F]{6}$/.test(clean)) {
                                var c = Qt.color("#" + clean);
                                if (c.hslHue >= 0) {
                                    Flags.manualHue = Math.round(c.hslHue * 359);
                                    Flags.manualSat = c.hslSaturation;
                                } else {
                                    Flags.manualSat = 0;
                                }
                                root.applyManual();
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()
                    }

                    Rectangle {
                        anchors.left: hexField.left
                        anchors.right: hexField.right
                        anchors.top: hexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: hexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        SettingsRow {
            id: randomRow
            surface: root
            name: root.randomEntry.label
            icon: "monitor"

            SettingsSeg {
                s: root.s
                options: root.randomEntry.options
                value: Store.get("randomScope")
                onPicked: (v) => Store.set("randomScope", v)
            }
        }

        SettingsRow {
            id: scaleRow
            surface: root
            name: root.scaleEntry.label
            icon: "scaling"

            SettingsSeg {
                s: root.s
                options: root.scaleEntry.options
                value: Store.get("uiScale")
                onPicked: (v) => Store.set("uiScale", v)
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            name: root.motionEntry.label
            icon: "waves"

            LinkToggle {
                s: root.s
                on: Store.get("reduceMotion")
                onToggled: Store.set("reduceMotion", !Store.get("reduceMotion"))
            }
        }

        SettingsRow {
            id: fontRow
            surface: root
            name: root.fontEntry.label
            icon: "type"
            sub: Store.get("uiFont").length > 0 ? Store.get("uiFont") : "Inter"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === fontRow ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
    }
}
