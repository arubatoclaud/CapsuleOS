pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * LOOK sub-surface: edits the window-decoration knobs that live in
 * decoration.lua, the night-light schedule, and the pill's own chrome. Every
 * row reads and writes through Store, which owns decoration.lua/ghostty's
 * config, validates against Schema, rewrites the right field and debounces the
 * Hyprland reload (or, for the terminal row, rewrites ghostty's
 * background-opacity and pokes it with SIGUSR2) — so this surface carries no
 * write plumbing of its own at all: no FileView, no writer, no reload timer.
 *
 * The pill-blur toggle that used to sit above Material is gone (audit P0-2):
 * blur behind the pill was never independent state, it was what a translucent
 * material implies, and the two controls could be left disagreeing. Material
 * owns it now — Store adds or removes decoration.lua's `pill-blur` layer_rule
 * as the material changes, and `seed` asks Store to reconcile the rule with
 * the material on every open so a hand edit of the Lua cannot leave them
 * apart.
 *
 * Reached from the settings index; morphs back on the back chevron.
 */
SettingsSurface {
    id: root

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
    readonly property var materialEntry: Schema.settings.material
    readonly property var autoHideEntry: Schema.settings.autoHide
    readonly property var autoHideDelayEntry: Schema.settings.autoHideDelay

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

        // Material is the control, the layer_rule is the state it implies, and
        // nothing but Store writes either — but a hand edit of decoration.lua
        // can still separate them, so the rule is put back in line on open. A
        // no-op (and no file write, no reload) when they already agree.
        Store.syncPillBlurRule();

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
                settingId: "gapsIn"
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
                settingId: "gapsOut"
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
                settingId: "rounding"
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
                settingId: "roundingPower"
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
                settingId: "borderSize"
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
                settingId: "resizeOnBorder"
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
                settingId: "layout"
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
                settingId: "nightLightMode"
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
                settingId: "nightLightTemp"
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
                settingId: "nightLightOnMin"
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
                settingId: "nightLightOffMin"
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
                settingId: "shadowEnabled"
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
                settingId: "shadowRange"
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
                settingId: "shadowRenderPower"
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
                settingId: "blurEnabled"
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
                settingId: "blurSize"
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
                settingId: "blurPasses"
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
                settingId: "blurVibrancy"
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
                settingId: "blurNoise"
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
                settingId: "activeOpacity"
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
                settingId: "inactiveOpacity"
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
                settingId: "termBgOpacity"
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
                settingId: "topGap"
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
                settingId: "appGap"
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
                settingId: "pillOpacity"
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

            /**
             * A plain `Store.set` like every other row: Store writes the flag
             * and, because the material is also the pill's blur, adds or removes
             * decoration.lua's `pill-blur` layer_rule in the same call. Glass
             * and frost are translucent and want the frosted glass behind them;
             * ink is flat opaque, where blurring only costs GPU time.
             */
            SettingsRow {
                id: materialRow
                surface: root
                settingId: "material"
                name: root.materialEntry.label
                sub: root.materialEntry.caption
                captionOnFocus: true
                SettingsSeg {
                    s: root.s
                    options: root.materialEntry.options
                    value: Store.get("material")
                    onPicked: v => Store.set("material", v)
                }
            }

            SettingsRow {
                id: autoHideRow
                surface: root
                settingId: "autoHide"
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
                settingId: "autoHideDelay"
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
