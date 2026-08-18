pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * WINDOWS sub-surface (Schema page id `look`): edits the window-decoration
 * knobs that live in decoration.lua — gaps, corners, borders, the tiling
 * layout, shadow, blur and transparency. Every row reads and writes through
 * Store, which owns decoration.lua/ghostty's config, validates against
 * Schema, rewrites the right field and debounces the Hyprland reload (or, for
 * the Ghostty background row, rewrites ghostty's background-opacity and
 * pokes it with SIGUSR2) — so this surface carries no write plumbing of its
 * own at all: no FileView, no writer, no reload timer.
 *
 * Night light (Display) and the pill's own chrome plus Material (Appearance)
 * used to live here; both moved out in the settings restructure so this page
 * is window decoration only.
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
    readonly property var layoutEntry: Schema.settings.layout

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
            termBgOpacity: Store.get("termBgOpacity")
        };
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
            title: "WINDOWS"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            SettingsGroup { id: winGrp; s: root.s; title: Schema.groupTitle("look", "window"); open: true

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
                last: true
                ScrubValue {
                    id: borderScrub
                    s: root.s
                    value: Store.get("borderSize")
                    openValue: root.base.borderSize
                    from: root.borderSizeEntry.from; to: root.borderSizeEntry.to; step: root.borderSizeEntry.step; unit: root.borderSizeEntry.unit
                    onEdited: v => Store.set("borderSize", v)
                }
            }

            }

            SettingsGroup { id: layoutGrp; s: root.s; title: Schema.groupTitle("look", "layout")

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

            SettingsGroup { id: shadowGrp; s: root.s; title: Schema.groupTitle("look", "shadow")

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

            SettingsGroup { id: blurGrp; s: root.s; title: Schema.groupTitle("look", "blur")

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

            SettingsGroup { id: opGrp; s: root.s; title: Schema.groupTitle("look", "opacity")

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

            Item { width: 1; height: 10 * root.s }
        }
    }
}
