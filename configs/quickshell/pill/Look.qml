pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "lib/setDeco.js" as SetDeco
import "Singletons"

/**
 * LOOK sub-surface: edits the window-decoration knobs that live in
 * decoration.lua, the night-light schedule, and the pill's own chrome. Every
 * row reads and writes through Store, which owns decoration.lua/ghostty's
 * config, validates against Schema, rewrites the right field and debounces the
 * Hyprland reload (or, for the terminal row, rewrites ghostty's
 * background-opacity and pokes it with SIGUSR2) — so this surface carries no
 * write plumbing of its own beyond the two rows below.
 *
 * `Pill blur` and `Material` are the deliberate exception to "everything
 * writes through Store.set": both also have to add or remove the pill-blur
 * `hl.layer_rule` in decoration.lua, which is not a Schema field Store can
 * route (the live config parser rejects a runtime `layerrule` keyword, so the
 * rule has to be written into the Lua source). A bare `Store.set` on either
 * flag would persist it without touching the rule, so `setPillBlur` and
 * `setMaterial` set the flag through Store and then drive the rule through a
 * small local FileView pair, reading fresh off disk immediately before every
 * write so a Store-routed deco write moments earlier is never clobbered.
 * Task 8 removes the `pillBlur` flag and derives it from Material instead.
 *
 * Reached from the settings index; morphs back on the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    readonly property var gapsInEntry: Schema.settings.gapsIn
    readonly property var gapsOutEntry: Schema.settings.gapsOut
    readonly property var roundingEntry: Schema.settings.rounding
    readonly property var roundingPowerEntry: Schema.settings.roundingPower
    readonly property var borderSizeEntry: Schema.settings.borderSize
    readonly property var resizeOnBorderEntry: Schema.settings.resizeOnBorder
    readonly property var layoutEntry: Schema.settings.layout

    readonly property var nightLightModeEntry: Schema.settings.nightLightMode
    readonly property var nightLightTempEntry: Schema.settings.nightLightTemp
    readonly property var nightLightOnMinEntry: Schema.settings.nightLightOnMin
    readonly property var nightLightOffMinEntry: Schema.settings.nightLightOffMin

    readonly property var shadowEnabledEntry: Schema.settings.shadowEnabled
    readonly property var shadowRangeEntry: Schema.settings.shadowRange
    readonly property var shadowRenderPowerEntry: Schema.settings.shadowRenderPower

    readonly property var blurEnabledEntry: Schema.settings.blurEnabled
    readonly property var blurSizeEntry: Schema.settings.blurSize
    readonly property var blurPassesEntry: Schema.settings.blurPasses
    readonly property var blurVibrancyEntry: Schema.settings.blurVibrancy
    readonly property var blurNoiseEntry: Schema.settings.blurNoise

    readonly property var activeOpacityEntry: Schema.settings.activeOpacity
    readonly property var inactiveOpacityEntry: Schema.settings.inactiveOpacity
    readonly property var termBgOpacityEntry: Schema.settings.termBgOpacity

    readonly property var topGapEntry: Schema.settings.topGap
    readonly property var appGapEntry: Schema.settings.appGap
    readonly property var pillOpacityEntry: Schema.settings.pillOpacity
    readonly property var pillBlurEntry: Schema.settings.pillBlur
    readonly property var materialEntry: Schema.settings.material
    readonly property var autoHideEntry: Schema.settings.autoHide
    readonly property var autoHideDelayEntry: Schema.settings.autoHideDelay

    /**
     * Row registry, rebound whenever a group folds or a dependent toggle flips so
     * keyboard navigation never lands on a hidden line. Scrub rows expose a bump
     * that steps their ScrubValue one increment.
     */
    rows: {
        var r = [];
        if (winGrp.open) {
            r.push({ item: gapsInRow, kind: "scrub", bump: function (d) { gapsInScrub.bump(d); } });
            r.push({ item: gapsOutRow, kind: "scrub", bump: function (d) { gapsOutScrub.bump(d); } });
            r.push({ item: roundRow, kind: "scrub", bump: function (d) { roundScrub.bump(d); } });
            r.push({ item: roundPowRow, kind: "scrub", bump: function (d) { roundPowScrub.bump(d); } });
            r.push({ item: borderRow, kind: "scrub", bump: function (d) { borderScrub.bump(d); } });
            r.push({ item: resizeRow, kind: "toggle", get: function () { return Store.get("resizeOnBorder"); }, set: function (v) { Store.set("resizeOnBorder", v); } });
            r.push({ item: layoutRow, kind: "seg", vals: root.layoutEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("layout"); }, set: function (v) { Store.set("layout", v); } });
        }
        if (nightGrp.open) {
            r.push({ item: nlModeRow, kind: "seg", vals: root.nightLightModeEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("nightLightMode"); }, set: function (v) { Store.set("nightLightMode", v); } });
            if (Store.get("nightLightMode") !== "off")
                r.push({ item: nlTempRow, kind: "scrub", bump: function (d) { nlTempScrub.bump(d); } });
            if (Store.get("nightLightMode") === "scheduled") {
                r.push({ item: nlOnRow, kind: "scrub", bump: function (d) { nlOnScrub.bump(d); } });
                r.push({ item: nlOffRow, kind: "scrub", bump: function (d) { nlOffScrub.bump(d); } });
            }
        }
        if (shadowGrp.open) {
            r.push({ item: shEnRow, kind: "toggle", get: function () { return Store.get("shadowEnabled"); }, set: function (v) { Store.set("shadowEnabled", v); } });
            if (Store.get("shadowEnabled")) {
                r.push({ item: shRangeRow, kind: "scrub", bump: function (d) { shRangeScrub.bump(d); } });
                r.push({ item: shPowRow, kind: "scrub", bump: function (d) { shPowScrub.bump(d); } });
            }
        }
        if (blurGrp.open) {
            r.push({ item: blEnRow, kind: "toggle", get: function () { return Store.get("blurEnabled"); }, set: function (v) { Store.set("blurEnabled", v); } });
            if (Store.get("blurEnabled")) {
                r.push({ item: blSizeRow, kind: "scrub", bump: function (d) { blSizeScrub.bump(d); } });
                r.push({ item: blPassRow, kind: "scrub", bump: function (d) { blPassScrub.bump(d); } });
                r.push({ item: blVibRow, kind: "scrub", bump: function (d) { blVibScrub.bump(d); } });
                r.push({ item: blNoiseRow, kind: "scrub", bump: function (d) { blNoiseScrub.bump(d); } });
            }
        }
        if (opGrp.open) {
            r.push({ item: opActRow, kind: "scrub", bump: function (d) { opActScrub.bump(d); } });
            r.push({ item: opInactRow, kind: "scrub", bump: function (d) { opInactScrub.bump(d); } });
            r.push({ item: opTermRow, kind: "scrub", bump: function (d) { opTermScrub.bump(d); } });
        }
        if (pillGrp.open) {
            r.push({ item: pillGapRow, kind: "scrub", bump: function (d) { pillGapScrub.bump(d); } });
            r.push({ item: appGapRow, kind: "scrub", bump: function (d) { appGapScrub.bump(d); } });
            r.push({ item: pillOpRow, kind: "scrub", bump: function (d) { pillOpScrub.bump(d); } });
            r.push({ item: pillBlurRow, kind: "toggle", get: function () { return Store.get("pillBlur"); }, set: function (v) { root.setPillBlur(v); } });
            r.push({ item: materialRow, kind: "seg", vals: root.materialEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("material"); }, set: function (v) { root.setMaterial(v); } });
            r.push({ item: autoHideRow, kind: "toggle", get: function () { return Store.get("autoHide"); }, set: function (v) { Store.set("autoHide", v); } });
            if (Store.get("autoHide"))
                r.push({ item: hideDelayRow, kind: "seg", vals: root.autoHideDelayEntry.options.map(function (o) { return o.value; }), get: function () { return Store.get("autoHideDelay"); }, set: function (v) { Store.set("autoHideDelay", v); } });
        }
        return r;
    }

    readonly property string pillBlurRule: 'hl.layer_rule({ name = "pill-blur", match = { namespace = "pill" }, blur = true, ignore_alpha = 0.5 })\n'

    /** Per-field values captured on each open; the ScrubValue undo glyphs revert to these. */
    property var base: ({})

    onActiveChanged: {
        if (active) {
            seed();
        } else {
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

        // Re-derives the pillBlur flag from decoration.lua's actual layer_rule
        // state, exactly as before: a crash between writing the rule and
        // persisting the flag (or a hand edit of decoration.lua) must not leave
        // the toggle showing a state the rule doesn't back.
        decoFile.reload();
        var hasRule = SetDeco.hasNamedRule(decoFile.text(), "pill-blur");
        if (hasRule !== Store.get("pillBlur"))
            Store.set("pillBlur", hasRule);

        root.base = {
            gapsIn: Store.get("gapsIn"),
            gapsOut: Store.get("gapsOut"),
            rounding: Store.get("rounding"),
            roundingPower: Store.get("roundingPower"),
            borderSize: Store.get("borderSize"),
            shadowRange: Store.get("shadowRange"),
            shadowRenderPower: Store.get("shadowRenderPower"),
            blurSize: Store.get("blurSize"),
            blurPasses: Store.get("blurPasses"),
            blurVibrancy: Store.get("blurVibrancy"),
            blurNoise: Store.get("blurNoise"),
            activeOpacity: Store.get("activeOpacity"),
            inactiveOpacity: Store.get("inactiveOpacity"),
            termBgOpacity: Store.get("termBgOpacity"),
            pillOpacity: Store.get("pillOpacity"),
            topGap: Store.get("topGap"),
            appGap: Store.get("appGap"),
            nlTemp: Store.get("nightLightTemp"),
            nlOnMin: Store.get("nightLightOnMin"),
            nlOffMin: Store.get("nightLightOffMin")
        };
    }

    /** Minutes-since-midnight rendered as HH:MM for the schedule scrubs. */
    function fmtClock(v) {
        var h = Math.floor(v / 60);
        var m = v % 60;
        return h + ":" + (m < 10 ? "0" + m : m);
    }

    /**
     * Flips the pill-blur flag through Store and keeps the Hyprland layer_rule
     * in sync so the frosted-glass effect behind the pill actually turns on or
     * off. `pillBlur` is a bare Store flags entry — Store.set alone would
     * persist the flag without touching decoration.lua's layer_rule, so the
     * rule toggle stays local until Task 8 derives pillBlur from Material and
     * removes the flag.
     */
    function setPillBlur(on) {
        Store.set("pillBlur", on);
        root.applyPillBlur(on);
    }

    /**
     * Picks the surface material and keeps the Hyprland side honest: glass and
     * frost are translucent, so the pill wants the blur layer rule behind it,
     * while ink is flat opaque and blurring behind it only costs GPU time.
     */
    function setMaterial(v) {
        Store.set("material", v);
        root.setPillBlur(v !== "ink");
    }

    /**
     * Adds or removes the pill-blur layer_rule in decoration.lua and reloads
     * Hyprland so the frosted-glass effect behind the pill turns on or off at
     * once. Reads fresh off disk immediately before writing (`decoFile` is
     * `blockAllReads`, so `reload()` then `text()` is a synchronous fresh read)
     * so a Store-routed deco write moments earlier — gaps, rounding, blur,
     * shadow, opacity — is never clobbered by a rule edit built on a stale
     * snapshot. `decoWriter` is `blockWrites`, so `setText` lands on disk
     * synchronously before this function returns, closing the Look→Store
     * direction of the two-writer race on decoration.lua: Store can no longer
     * read stale (pre-rule) text right after this call. The Store→Look
     * direction — a Store deco write landing in the instant between this
     * function's fresh read and its own write — is accepted-transitional
     * until Task 8 retires this local writer pair along with the `pillBlur`
     * flag. Store's own resync happens in `decoWriter.onSaved` below, not
     * here, so it never fires before the write it is meant to observe.
     */
    function applyPillBlur(on) {
        decoFile.reload();
        var t = decoFile.text();
        var res;
        if (on) {
            if (SetDeco.hasNamedRule(t, "pill-blur")) {
                Store.reload();
                return;
            }
            res = SetDeco.addNamedRule(t, root.pillBlurRule);
        } else {
            res = SetDeco.removeNamedRule(t, "pill-blur");
        }
        if (!res.ok) {
            Store.reload();
            return;
        }
        decoWriter.setText(res.text);
        reloadTimer.restart();
    }

    FileView {
        id: decoFile
        path: Store.decoPath
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    /**
     * `blockWrites` makes `setText` land on disk synchronously rather than
     * asynchronously, so `applyPillBlur`'s rule edit can never be read as
     * stale by a Store write that starts a moment later. `onSaved` only then
     * tells Store to resync its own cached text — doing that right after
     * `setText` instead (as an earlier draft did) would deterministically
     * cache the pre-write text, since a plain `setText` save is async.
     */
    FileView {
        id: decoWriter
        path: Store.decoPath
        atomicWrites: true
        blockWrites: true
        printErrors: false
        onSaved: Store.reload()
    }

    /**
     * Reload is debounced so a fast pill-blur/material double-tap writes the
     * file per step but reloads Hyprland once. A failed reload is surfaced
     * through the same `Store.writeFailed` note strip every other row's write
     * uses, rather than a local note only this rule's toggle would show.
     */
    Timer {
        id: reloadTimer
        interval: 250
        repeat: false
        onTriggered: reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["sh", "-c", "sleep 0.3; hyprctl reload"]
        onExited: function (exitCode) {
            if (exitCode !== 0)
                Store.writeFailed("material", "Hyprland reload failed. The change is saved but not applied.");
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
            glyph: "\uf1fc"
            title: "LOOK"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            SettingsGroup { id: winGrp; s: root.s; title: "Window"; open: true

            SettingsRow {
                id: gapsInRow
                surface: root
                name: root.gapsInEntry.label
                sub: root.gapsInEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: gapsInScrub
                    s: root.s
                    value: Store.get("gapsIn")
                    openValue: root.base.gapsIn
                    from: root.gapsInEntry.from; to: root.gapsInEntry.to; step: root.gapsInEntry.step; unit: root.gapsInEntry.unit
                    onEdited: v => Store.set("gapsIn", v)
                }
            }

            SettingsRow {
                id: gapsOutRow
                surface: root
                name: root.gapsOutEntry.label
                sub: root.gapsOutEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: gapsOutScrub
                    s: root.s
                    value: Store.get("gapsOut")
                    openValue: root.base.gapsOut
                    from: root.gapsOutEntry.from; to: root.gapsOutEntry.to; step: root.gapsOutEntry.step; unit: root.gapsOutEntry.unit
                    onEdited: v => Store.set("gapsOut", v)
                }
            }

            SettingsRow {
                id: roundRow
                surface: root
                name: root.roundingEntry.label
                sub: root.roundingEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: roundScrub
                    s: root.s
                    value: Store.get("rounding")
                    openValue: root.base.rounding
                    from: root.roundingEntry.from; to: root.roundingEntry.to; step: root.roundingEntry.step; unit: root.roundingEntry.unit
                    onEdited: v => Store.set("rounding", v)
                }
            }

            SettingsRow {
                id: roundPowRow
                surface: root
                name: root.roundingPowerEntry.label
                sub: root.roundingPowerEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: roundPowScrub
                    s: root.s
                    value: Store.get("roundingPower")
                    openValue: root.base.roundingPower
                    from: root.roundingPowerEntry.from; to: root.roundingPowerEntry.to; step: root.roundingPowerEntry.step
                    onEdited: v => Store.set("roundingPower", v)
                }
            }

            SettingsRow {
                id: borderRow
                surface: root
                name: root.borderSizeEntry.label
                sub: root.borderSizeEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: borderScrub
                    s: root.s
                    value: Store.get("borderSize")
                    openValue: root.base.borderSize
                    from: root.borderSizeEntry.from; to: root.borderSizeEntry.to; step: root.borderSizeEntry.step; unit: root.borderSizeEntry.unit
                    onEdited: v => Store.set("borderSize", v)
                }
            }

            SettingsRow {
                id: resizeRow
                surface: root
                name: root.resizeOnBorderEntry.label
                sub: root.resizeOnBorderEntry.caption
                captionOnFocus: true
                LinkToggle {
                    s: root.s
                    on: Store.get("resizeOnBorder")
                    onToggled: Store.set("resizeOnBorder", !Store.get("resizeOnBorder"))
                }
            }

            SettingsRow {
                id: layoutRow
                surface: root
                name: root.layoutEntry.label
                sub: root.layoutEntry.caption
                captionOnFocus: true
                last: true
                SettingsSeg {
                    s: root.s
                    options: root.layoutEntry.options
                    value: Store.get("layout")
                    onPicked: v => Store.set("layout", v)
                }
            }

            }

            SettingsGroup { id: nightGrp; s: root.s; title: "Night light"

            SettingsRow {
                id: nlModeRow
                surface: root
                name: root.nightLightModeEntry.label
                sub: root.nightLightModeEntry.caption
                captionOnFocus: true
                last: Store.get("nightLightMode") === "off"
                SettingsSeg {
                    s: root.s
                    options: root.nightLightModeEntry.options
                    value: Store.get("nightLightMode")
                    onPicked: v => Store.set("nightLightMode", v)
                }
            }

            SettingsRow {
                id: nlTempRow
                surface: root
                name: root.nightLightTempEntry.label
                sub: root.nightLightTempEntry.caption
                captionOnFocus: true
                visible: Store.get("nightLightMode") !== "off"
                last: Store.get("nightLightMode") === "on"
                ScrubValue {
                    id: nlTempScrub
                    s: root.s
                    value: Store.get("nightLightTemp")
                    openValue: root.base.nlTemp
                    from: root.nightLightTempEntry.from; to: root.nightLightTempEntry.to; step: root.nightLightTempEntry.step; unit: root.nightLightTempEntry.unit
                    onEdited: v => Store.set("nightLightTemp", v)
                }
            }

            SettingsRow {
                id: nlOnRow
                surface: root
                name: root.nightLightOnMinEntry.label
                sub: root.nightLightOnMinEntry.caption
                captionOnFocus: true
                visible: Store.get("nightLightMode") === "scheduled"
                ScrubValue {
                    id: nlOnScrub
                    s: root.s
                    value: Store.get("nightLightOnMin")
                    openValue: root.base.nlOnMin
                    from: root.nightLightOnMinEntry.from; to: root.nightLightOnMinEntry.to; step: root.nightLightOnMinEntry.step
                    fmt: root.fmtClock
                    onEdited: v => Store.set("nightLightOnMin", v)
                }
            }

            SettingsRow {
                id: nlOffRow
                surface: root
                name: root.nightLightOffMinEntry.label
                sub: root.nightLightOffMinEntry.caption
                captionOnFocus: true
                visible: Store.get("nightLightMode") === "scheduled"
                last: true
                ScrubValue {
                    id: nlOffScrub
                    s: root.s
                    value: Store.get("nightLightOffMin")
                    openValue: root.base.nlOffMin
                    from: root.nightLightOffMinEntry.from; to: root.nightLightOffMinEntry.to; step: root.nightLightOffMinEntry.step
                    fmt: root.fmtClock
                    onEdited: v => Store.set("nightLightOffMin", v)
                }
            }

            }

            SettingsGroup { id: shadowGrp; s: root.s; title: "Shadow"

            SettingsRow {
                id: shEnRow
                surface: root
                name: root.shadowEnabledEntry.label
                sub: root.shadowEnabledEntry.caption
                captionOnFocus: true
                last: !Store.get("shadowEnabled")
                LinkToggle {
                    s: root.s
                    on: Store.get("shadowEnabled")
                    onToggled: Store.set("shadowEnabled", !Store.get("shadowEnabled"))
                }
            }

            SettingsRow {
                id: shRangeRow
                surface: root
                name: root.shadowRangeEntry.label
                sub: root.shadowRangeEntry.caption
                captionOnFocus: true
                visible: Store.get("shadowEnabled")
                ScrubValue {
                    id: shRangeScrub
                    s: root.s
                    value: Store.get("shadowRange")
                    openValue: root.base.shadowRange
                    from: root.shadowRangeEntry.from; to: root.shadowRangeEntry.to; step: root.shadowRangeEntry.step; unit: root.shadowRangeEntry.unit
                    onEdited: v => Store.set("shadowRange", v)
                }
            }

            SettingsRow {
                id: shPowRow
                surface: root
                name: root.shadowRenderPowerEntry.label
                sub: root.shadowRenderPowerEntry.caption
                captionOnFocus: true
                visible: Store.get("shadowEnabled")
                last: true
                ScrubValue {
                    id: shPowScrub
                    s: root.s
                    value: Store.get("shadowRenderPower")
                    openValue: root.base.shadowRenderPower
                    from: root.shadowRenderPowerEntry.from; to: root.shadowRenderPowerEntry.to; step: root.shadowRenderPowerEntry.step
                    onEdited: v => Store.set("shadowRenderPower", v)
                }
            }

            }

            SettingsGroup { id: blurGrp; s: root.s; title: "Blur"

            SettingsRow {
                id: blEnRow
                surface: root
                name: root.blurEnabledEntry.label
                sub: root.blurEnabledEntry.caption
                captionOnFocus: true
                last: !Store.get("blurEnabled")
                LinkToggle {
                    s: root.s
                    on: Store.get("blurEnabled")
                    onToggled: Store.set("blurEnabled", !Store.get("blurEnabled"))
                }
            }

            SettingsRow {
                id: blSizeRow
                surface: root
                name: root.blurSizeEntry.label
                sub: root.blurSizeEntry.caption
                captionOnFocus: true
                visible: Store.get("blurEnabled")
                ScrubValue {
                    id: blSizeScrub
                    s: root.s
                    value: Store.get("blurSize")
                    openValue: root.base.blurSize
                    from: root.blurSizeEntry.from; to: root.blurSizeEntry.to; step: root.blurSizeEntry.step; unit: root.blurSizeEntry.unit
                    onEdited: v => Store.set("blurSize", v)
                }
            }

            SettingsRow {
                id: blPassRow
                surface: root
                name: root.blurPassesEntry.label
                sub: root.blurPassesEntry.caption
                captionOnFocus: true
                visible: Store.get("blurEnabled")
                ScrubValue {
                    id: blPassScrub
                    s: root.s
                    value: Store.get("blurPasses")
                    openValue: root.base.blurPasses
                    from: root.blurPassesEntry.from; to: root.blurPassesEntry.to; step: root.blurPassesEntry.step
                    onEdited: v => Store.set("blurPasses", v)
                }
            }

            SettingsRow {
                id: blVibRow
                surface: root
                name: root.blurVibrancyEntry.label
                sub: root.blurVibrancyEntry.caption
                captionOnFocus: true
                visible: Store.get("blurEnabled")
                ScrubValue {
                    id: blVibScrub
                    s: root.s
                    value: Store.get("blurVibrancy")
                    openValue: root.base.blurVibrancy
                    from: root.blurVibrancyEntry.from; to: root.blurVibrancyEntry.to; step: root.blurVibrancyEntry.step; decimals: 2
                    onEdited: v => Store.set("blurVibrancy", v)
                }
            }

            SettingsRow {
                id: blNoiseRow
                surface: root
                name: root.blurNoiseEntry.label
                sub: root.blurNoiseEntry.caption
                captionOnFocus: true
                visible: Store.get("blurEnabled")
                last: true
                ScrubValue {
                    id: blNoiseScrub
                    s: root.s
                    value: Store.get("blurNoise")
                    openValue: root.base.blurNoise
                    from: root.blurNoiseEntry.from; to: root.blurNoiseEntry.to; step: root.blurNoiseEntry.step; decimals: 2
                    onEdited: v => Store.set("blurNoise", v)
                }
            }

            }

            SettingsGroup { id: opGrp; s: root.s; title: "Opacity"

            SettingsRow {
                id: opActRow
                surface: root
                name: root.activeOpacityEntry.label
                sub: root.activeOpacityEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: opActScrub
                    s: root.s
                    value: Store.get("activeOpacity")
                    openValue: root.base.activeOpacity
                    from: root.activeOpacityEntry.from; to: root.activeOpacityEntry.to; step: root.activeOpacityEntry.step; decimals: 2
                    onEdited: v => Store.set("activeOpacity", v)
                }
            }

            SettingsRow {
                id: opInactRow
                surface: root
                name: root.inactiveOpacityEntry.label
                sub: root.inactiveOpacityEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: opInactScrub
                    s: root.s
                    value: Store.get("inactiveOpacity")
                    openValue: root.base.inactiveOpacity
                    from: root.inactiveOpacityEntry.from; to: root.inactiveOpacityEntry.to; step: root.inactiveOpacityEntry.step; decimals: 2
                    onEdited: v => Store.set("inactiveOpacity", v)
                }
            }

            SettingsRow {
                id: opTermRow
                surface: root
                name: root.termBgOpacityEntry.label
                sub: root.termBgOpacityEntry.caption
                captionOnFocus: true
                last: true
                ScrubValue {
                    id: opTermScrub
                    s: root.s
                    value: Store.get("termBgOpacity")
                    openValue: root.base.termBgOpacity
                    from: root.termBgOpacityEntry.from; to: root.termBgOpacityEntry.to; step: root.termBgOpacityEntry.step; decimals: 2
                    onEdited: v => Store.set("termBgOpacity", v)
                }
            }

            }

            SettingsGroup { id: pillGrp; s: root.s; title: "Pill"

            SettingsRow {
                id: pillGapRow
                surface: root
                name: root.topGapEntry.label
                sub: root.topGapEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: pillGapScrub
                    s: root.s
                    value: Store.get("topGap")
                    openValue: root.base.topGap
                    from: root.topGapEntry.from; to: root.topGapEntry.to; step: root.topGapEntry.step; decimals: 1
                    onEdited: v => Store.set("topGap", v)
                }
            }

            SettingsRow {
                id: appGapRow
                surface: root
                name: root.appGapEntry.label
                sub: root.appGapEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: appGapScrub
                    s: root.s
                    value: Store.get("appGap")
                    openValue: root.base.appGap
                    from: root.appGapEntry.from; to: root.appGapEntry.to; step: root.appGapEntry.step; decimals: 1
                    onEdited: v => Store.set("appGap", v)
                }
            }

            SettingsRow {
                id: pillOpRow
                surface: root
                name: root.pillOpacityEntry.label
                sub: root.pillOpacityEntry.caption
                captionOnFocus: true
                ScrubValue {
                    id: pillOpScrub
                    s: root.s
                    value: Store.get("pillOpacity")
                    openValue: root.base.pillOpacity
                    from: root.pillOpacityEntry.from; to: root.pillOpacityEntry.to; step: root.pillOpacityEntry.step; decimals: 2
                    onEdited: v => Store.set("pillOpacity", v)
                }
            }

            SettingsRow {
                id: pillBlurRow
                surface: root
                name: root.pillBlurEntry.label
                sub: root.pillBlurEntry.caption
                captionOnFocus: true
                LinkToggle {
                    s: root.s
                    on: Store.get("pillBlur")
                    onToggled: root.setPillBlur(!Store.get("pillBlur"))
                }
            }

            SettingsRow {
                id: materialRow
                surface: root
                name: root.materialEntry.label
                sub: root.materialEntry.caption
                captionOnFocus: true
                SettingsSeg {
                    s: root.s
                    options: root.materialEntry.options
                    value: Store.get("material")
                    onPicked: v => root.setMaterial(v)
                }
            }

            SettingsRow {
                id: autoHideRow
                surface: root
                name: root.autoHideEntry.label
                sub: root.autoHideEntry.caption
                captionOnFocus: true
                last: !Store.get("autoHide")
                LinkToggle {
                    s: root.s
                    on: Store.get("autoHide")
                    onToggled: Store.set("autoHide", !Store.get("autoHide"))
                }
            }

            SettingsRow {
                id: hideDelayRow
                surface: root
                name: root.autoHideDelayEntry.label
                sub: root.autoHideDelayEntry.caption
                captionOnFocus: true
                visible: Store.get("autoHide")
                last: true
                SettingsSeg {
                    s: root.s
                    options: root.autoHideDelayEntry.options
                    value: Store.get("autoHideDelay")
                    onPicked: v => Store.set("autoHideDelay", v)
                }
            }

            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
