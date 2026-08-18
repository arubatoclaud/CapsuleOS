pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * MOTION sub-surface (Schema page id `animation`): toggles Hyprland animations
 * and picks the motion Feel, with the exact curve and the ready-made presets
 * folded away underneath, plus a Reduce motion toggle (moved here from
 * Appearance in the settings restructure) that scales every shell-side
 * animation duration via `Motion.mult` — independent of Hyprland's own
 * `Enabled` toggle above, so it stays visible whether or not Hyprland's
 * animations are on. Every Store-routed value reads and writes through Store,
 * which owns animations.lua, validates against Schema, rewrites the right
 * field and debounces the hyprctl reload — so this surface carries no write
 * plumbing of its own beyond the curve/speed formatting Store's `anim`
 * backend expects.
 *
 * Feel is the primary control (R3, audit P0-2): one pick sets the curve AND the
 * speed, which is the whole of the page's motion character. The bezier editor
 * and the Preset strip used to sit open beside it as a second, finer control
 * over the same curve, so the page offered two answers to one question and the
 * undo glyph could mean either. They now live in a collapsed `Curve` group —
 * present for anyone who wants the exact numbers, out of the way of the choice
 * that actually matters — and picking a Feel RESETS the revert baseline, so the
 * undo glyph has exactly one meaning: "back to the curve this Feel stamped".
 *
 * The bezier control points stay local properties rather than a live Store
 * binding, since a drag has to diverge from disk until release; they are
 * (re)seeded from Store on every open. The speed scrub and the curve share the
 * revert baseline snapshotted on that seed, restored by an undo glyph; it
 * survives leaving and reopening the tab so a curve change stays revertable
 * while you go watch it play. The editor's handle positions are the source of
 * truth — the curve point properties derive from them — so dragging a handle
 * never fights a binding.
 * Reached from the settings index; morphs back on the back chevron.
 *
 * The Feel character (`applyMotion`) is a deliberate exception to "everything
 * writes through Store.set": picking calm/spring/glide is Flags-backed but also
 * has to rewrite the pillMorph curve and retime every leaf, so a bare
 * `Store.set("motion", v)` would persist the flag and leave Hyprland on the old
 * curve. `applyMotion` sets `Flags.motion` directly and then drives the curve
 * and speed through the same `Store.set` calls the editor and Preset row use.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property bool animOn: Store.get("animEnabled")
    readonly property var enabledEntry: Schema.settings.animEnabled
    readonly property var motionEntry: Schema.settings.motion
    readonly property var speedEntry: Schema.settings.animSpeed
    readonly property var reduceMotionEntry: Schema.settings.reduceMotion
    property real speed: 3
    property var base: ({})

    /** Bezier control points, read 0..1 (y may overshoot); derived from the handles. */
    property real cx1: 0.23
    property real cy1: 1.0
    property real cx2: 0.32
    property real cy2: 1.0

    /**
     * Single source of truth for every curve preset — the calm/spring/glide
     * "character" curves `applyMotion` drives and the Smooth/Snappy/Linear
     * curve presets the Preset row offers — so the coordinates exist exactly
     * once instead of the three copies (an `applyMotion` ternary chain, this
     * table, and `snapToPreset`'s own candidates list) that used to drift.
     * `motion` entries also carry the paired Hyprland duration; `label` entries
     * are the ones the Preset row's SettingsSeg offers by name.
     */
    readonly property var presets: [
        { motion: "calm",   x1: 0.32, y1: 0.72, x2: 0.0,  y2: 1.0,  speed: 3.0 },
        { motion: "spring", x1: 0.34, y1: 1.56, x2: 0.64, y2: 1.0,  speed: 4.0 },
        { motion: "glide",  x1: 0.45, y1: 0.05, x2: 0.15, y2: 1.0,  speed: 5.2 },
        { label: "Smooth",  x1: 0.23, y1: 1.0,  x2: 0.32, y2: 1.0 },
        { label: "Snappy",  x1: 0.15, y1: 0.0,  x2: 0.1,  y2: 1.0 },
        { label: "Linear",  x1: 0.33, y1: 0.33, x2: 0.66, y2: 0.66 }
    ]

    function presetByMotion(v) {
        for (var i = 0; i < root.presets.length; i++)
            if (root.presets[i].motion === v)
                return root.presets[i];
        return null;
    }

    onActiveChanged: {
        if (active) {
            seed();
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Resyncs Store from disk, seeds the bezier handle properties and the
     * speed scrub from it, and snapshots the revert baseline. Runs on every
     * open — safe now that Store's pending-write counters keep this resync from
     * ever racing a write still landing on the same file.
     */
    function seed() {
        Store.reload();
        root.speed = Store.get("animSpeed");
        var pts = String(Store.get("animCurve")).split(",").map(function (n) { return parseFloat(n); });
        if (pts.length === 4 && pts.every(function (n) { return !isNaN(n); })) {
            root.cx1 = pts[0];
            root.cy1 = pts[1];
            root.cx2 = pts[2];
            root.cy2 = pts[3];
        }
        editor.syncHandles();
        root.base = { speed: root.speed, cx1: root.cx1, cy1: root.cy1, cx2: root.cx2, cy2: root.cy2 };
    }

    function writeEnabled(on) {
        Store.set("animEnabled", on);
    }

    function writeSpeed(v) {
        Store.set("animSpeed", v);
    }

    /**
     * Snaps the handle coordinates to a preset's exact values when a released
     * handle position lands within epsilon of all four of that preset's
     * coordinates, so nudging a handle and letting go near calm, spring,
     * glide, Smooth, Snappy or Linear persists the exact preset instead of a
     * decimal's worth of drag drift. A curve outside epsilon on any of the
     * four values is left untouched.
     */
    function snapToPreset() {
        var eps = 0.03;
        for (var i = 0; i < root.presets.length; i++) {
            var p = root.presets[i];
            if (Math.abs(root.cx1 - p.x1) <= eps && Math.abs(root.cy1 - p.y1) <= eps
                && Math.abs(root.cx2 - p.x2) <= eps && Math.abs(root.cy2 - p.y2) <= eps) {
                root.cx1 = p.x1; root.cy1 = p.y1; root.cx2 = p.x2; root.cy2 = p.y2;
                editor.syncHandles();
                return;
            }
        }
    }

    function writeCurve() {
        Store.set("animCurve", root.cx1.toFixed(2) + "," + root.cy1.toFixed(2) + "," + root.cx2.toFixed(2) + "," + root.cy2.toFixed(2));
    }

    /**
     * Sets the shell's motion character and pushes the same character down to
     * Hyprland, so windows and workspaces settle exactly like the pill does.
     * The curve points mirror Motion.morphCurve and the speed is the matching
     * Hyprland duration: calm lands, spring overshoots, glide stretches. Writes
     * through the surface's own curve and speed plumbing (Store's `anim`
     * backend), so the handles and the scrub follow what landed on disk.
     *
     * The revert baseline is RESET to what the pick just stamped, which is the
     * difference between Feel being the primary control and Feel being one more
     * way to move the curve (audit P0-2). Feel is a deliberate whole-character
     * choice, not a nudge: leaving the baseline behind, as this used to and as
     * the Preset row still does, armed the undo glyph the instant you picked a
     * character and offered to take you back to a curve you had already
     * replaced on purpose. Now the glyph appears only once you have drifted
     * away from the Feel you chose, and means one thing when it does.
     * `Flags.motion` is set directly rather than through `Store.set` — see the
     * header note on why the flag alone is not enough here.
     */
    function applyMotion(v) {
        Flags.motion = v;
        var p = root.presetByMotion(v);
        if (!p)
            return;
        root.cx1 = p.x1; root.cy1 = p.y1; root.cx2 = p.x2; root.cy2 = p.y2;
        editor.syncHandles();
        root.writeCurve();
        root.speed = p.speed;
        root.writeSpeed(root.speed);
        root.base = { speed: root.speed, cx1: root.cx1, cy1: root.cy1, cx2: root.cx2, cy2: root.cy2 };
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
            glyph: "\uf04b"
            title: "MOTION"
            showBack: true
        }

        SettingsGroupLabel { s: root.s; leftPadding: 12 * root.s; text: Schema.groupTitle("animation", "motion") }

        SettingsRow {
            id: enabledRow
            surface: root
            settingId: "animEnabled"
            navSet: (v) => root.writeEnabled(v)
            name: root.enabledEntry.label
            sub: root.enabledEntry.caption
            captionOnFocus: true
            icon: "sparkles"
            LinkToggle {
                s: root.s
                on: root.animOn
                onToggled: root.writeEnabled(!root.animOn)
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            settingId: "motion"
            navSet: (v) => root.applyMotion(v)
            name: root.motionEntry.label
            sub: root.motionEntry.caption
            captionOnFocus: true
            icon: "waves"
            visible: root.animOn
            SettingsSeg {
                s: root.s
                options: root.motionEntry.options
                value: Store.get("motion")
                onPicked: v => root.applyMotion(v)
            }
        }

        SettingsRow {
            id: speedRow
            surface: root
            settingId: "animSpeed"
            name: root.speedEntry.label
            sub: root.speedEntry.caption
            captionOnFocus: true
            icon: "bolt"
            visible: root.animOn
            ScrubValue {
                id: speedScrub
                s: root.s
                value: root.speed
                openValue: root.base.speed
                from: 1; to: 10; step: 0.5; decimals: 1
                onEdited: v => {
                    root.speed = v;
                    root.writeSpeed(v);
                }
            }
        }

        SettingsRow {
            id: reduceMotionRow
            surface: root
            settingId: "reduceMotion"
            name: root.reduceMotionEntry.label
            sub: root.reduceMotionEntry.caption
            captionOnFocus: true
            icon: "waves"
            last: true
            LinkToggle {
                s: root.s
                on: Store.get("reduceMotion")
                onToggled: Store.set("reduceMotion", !Store.get("reduceMotion"))
            }
        }

        /**
         * The exact curve, folded away. Everything in here edits what the Feel
         * row above already set, so it opens shut: the page reads as one motion
         * choice with the numbers available underneath, instead of two controls
         * over the same curve competing for the eye (audit P0-2). Collapsing it
         * also drops its rows out of keyboard navigation on its own — see
         * SettingsGroup.
         */
        SettingsGroup {
            s: root.s
            hPad: 12 * root.s
            title: Schema.groupTitle("animation", "curve")
            visible: root.animOn

            /**
             * Bezier editor. The square maps unit curve-space (0,0 bottom-left to
             * 1,1 top-right) to pixels with y inverted; the two handles are the
             * source of truth and the cx/cy properties read back from them. An undo
             * glyph appears whenever the live points drift from the on-open snapshot.
             *
             * Visibility is the group's business now, not this item's: `visible`
             * composes down the parent chain, so the fold hides the editor and
             * the group's own `visible: root.animOn` takes it out of the page
             * when animations are off. The height stays unconditional for the
             * same reason — a `visible ? … : 0` here reads 0 while the group is
             * shut, which is exactly when the fold measures what to open to, and
             * the expand would start toward the short height and retarget.
             */
            Item {
                id: editor
                width: parent.width
                height: square.height + 18 * root.s

                readonly property real es: 150 * root.s
                readonly property real r: 7 * root.s
                readonly property bool dirty: root.base.cx1 !== undefined
                    && (root.cx1 !== root.base.cx1 || root.cy1 !== root.base.cy1
                        || root.cx2 !== root.base.cx2 || root.cy2 !== root.base.cy2)

                function pxX(v) { return v * editor.es; }
                function pxY(v) { return editor.es - v * editor.es; }

                function commitFromHandles() {
                    root.cx1 = Math.max(0, Math.min(1, (h1.x + editor.r) / editor.es));
                    root.cy1 = 1 - (h1.y + editor.r) / editor.es;
                    root.cx2 = Math.max(0, Math.min(1, (h2.x + editor.r) / editor.es));
                    root.cy2 = 1 - (h2.y + editor.r) / editor.es;
                }

                function syncHandles() {
                    h1.x = editor.pxX(root.cx1) - editor.r;
                    h1.y = editor.pxY(root.cy1) - editor.r;
                    h2.x = editor.pxX(root.cx2) - editor.r;
                    h2.y = editor.pxY(root.cy2) - editor.r;
                }

                onVisibleChanged: if (visible) syncHandles()
                Component.onCompleted: syncHandles()
                Connections {
                    target: root
                    function onBaseChanged() { editor.syncHandles(); }
                }

                Item {
                    id: square
                    width: editor.es
                    height: editor.es
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 10 * root.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.hairSoft
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(Theme.cream, 0.12)
                            strokeWidth: 1
                            fillColor: "transparent"
                            startX: 0; startY: editor.es
                            PathLine { x: editor.es; y: 0 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(Theme.markGlow, 0.35)
                            strokeWidth: 1.2
                            fillColor: "transparent"
                            startX: 0; startY: editor.es
                            PathLine { x: editor.pxX(root.cx1); y: editor.pxY(root.cy1) }
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(Theme.markGlow, 0.35)
                            strokeWidth: 1.2
                            fillColor: "transparent"
                            startX: editor.es; startY: 0
                            PathLine { x: editor.pxX(root.cx2); y: editor.pxY(root.cy2) }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Theme.markGlow
                            strokeWidth: 2.4 * root.s
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 0; startY: editor.es
                            PathCubic {
                                control1X: editor.pxX(root.cx1); control1Y: editor.pxY(root.cy1)
                                control2X: editor.pxX(root.cx2); control2Y: editor.pxY(root.cy2)
                                x: editor.es; y: 0
                            }
                        }
                    }

                    Rectangle {
                        id: h1
                        width: 2 * editor.r
                        height: 2 * editor.r
                        radius: editor.r
                        color: h1drag.active ? Theme.bright : Theme.cream
                        border.width: 2
                        border.color: Theme.markGlow

                        DragHandler {
                            id: h1drag
                            target: h1
                            xAxis.minimum: -editor.r
                            xAxis.maximum: editor.es - editor.r
                            yAxis.minimum: -editor.r - 0.35 * editor.es
                            yAxis.maximum: editor.es - editor.r + 0.35 * editor.es
                            onActiveChanged: if (!active) { root.snapToPreset(); root.writeCurve(); }
                        }
                        onXChanged: if (h1drag.active) editor.commitFromHandles()
                        onYChanged: if (h1drag.active) editor.commitFromHandles()
                    }

                    Rectangle {
                        id: h2
                        width: 2 * editor.r
                        height: 2 * editor.r
                        radius: editor.r
                        color: h2drag.active ? Theme.bright : Theme.cream
                        border.width: 2
                        border.color: Theme.markGlow

                        DragHandler {
                            id: h2drag
                            target: h2
                            xAxis.minimum: -editor.r
                            xAxis.maximum: editor.es - editor.r
                            yAxis.minimum: -editor.r - 0.35 * editor.es
                            yAxis.maximum: editor.es - editor.r + 0.35 * editor.es
                            onActiveChanged: if (!active) { root.snapToPreset(); root.writeCurve(); }
                        }
                        onXChanged: if (h2drag.active) editor.commitFromHandles()
                        onYChanged: if (h2drag.active) editor.commitFromHandles()
                    }
                }

                GlyphIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.top: parent.top
                    anchors.topMargin: 4 * root.s
                    visible: editor.dirty
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "undo"
                    color: revertArea.containsMouse ? Theme.bright : Qt.alpha(Theme.markGlow, 0.6)
                    stroke: 1.9

                    MouseArea {
                        id: revertArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cx1 = root.base.cx1; root.cy1 = root.base.cy1;
                            root.cx2 = root.base.cx2; root.cy2 = root.base.cy2;
                            editor.syncHandles();
                            root.writeCurve();
                        }
                    }
                }
            }

            /**
             * Preset and the curve editor above it stay mouse-only, and so claim no
             * nav slot: a 2D handle drag has no single bump axis, and the preset
             * strip is a one-shot stamp rather than a value to cycle.
             */
            SettingsRow {
                surface: root
                name: Schema.settings.animPreset.label
                sub: Schema.settings.animPreset.caption
                captionOnFocus: true
                icon: "waves"
                last: true
                SettingsSeg {
                    s: root.s
                    options: root.presets.filter(function (p) { return p.label; }).map(function (p) { return { label: p.label, value: p.label }; })
                    value: ""
                    onPicked: (v) => {
                        for (var i = 0; i < root.presets.length; i++) {
                            if (root.presets[i].label === v) {
                                var p = root.presets[i];
                                root.cx1 = p.x1; root.cy1 = p.y1; root.cx2 = p.x2; root.cy2 = p.y2;
                                editor.syncHandles();
                                root.writeCurve();
                                break;
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 10 * root.s }
    }
}
