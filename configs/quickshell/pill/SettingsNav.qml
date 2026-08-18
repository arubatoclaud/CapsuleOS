pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * One row's claim on its page's keyboard navigation.
 *
 * Every settings page used to carry a hand-written `rows: [...]` registry that
 * restated, line by line, each row's control kind, its getter and setter, and
 * the very visibility condition already spelled out on the row itself — two
 * books kept by hand, drifting apart the moment a row was added or folded away
 * (audit P1-7). A row now claims its own slot instead: it drops one of these
 * beside itself, and the enclosing SettingsSurface derives the whole navigable
 * list from the claims that are currently visible, ordered by where they sit
 * on screen.
 *
 * `item` is the row the soul seam tracks, and its *effective* visibility gates
 * the claim: QML already composes `visible` down the parent chain, so a row
 * inside a collapsed SettingsGroup or an unselected monitor card reports false
 * and drops out of navigation without anyone having to say so a second time.
 *
 * Everything else defaults off `settingId`: the Schema entry supplies the
 * control kind and, for segmented rows, the values to cycle, while reads and
 * writes go through Store. A row whose write needs more than a bare `Store.set`
 * (Appearance's palette apply, Animation's Feel) hands over `navSet`; the
 * bespoke lines with no Schema id at all (Display's monitor card, the
 * cursor-theme picker, the index's category rows) state `navKind` or
 * `navTarget` outright. Scrub rows need nothing: `bump` finds the ScrubValue
 * sitting in the row's own control slot.
 *
 * SettingsRow carries one of these internally and forwards the `nav*`
 * properties, so a plain row only ever writes `settingId: "gapsIn"`.
 */
QtObject {
    id: nav

    /** The row this claim stands for: hover target, seam anchor and sort key. */
    property Item item: null
    /** The enclosing SettingsSurface; the claim is inert until this is set. */
    property var surface: null

    /** Schema id backing the row; drives kind, seg values and the default get/set. */
    property string settingId: ""
    /** Control kind for rows Schema does not describe; otherwise derived. */
    property string navKind: ""
    /** Sub-surface a nav row opens. A non-empty value alone implies kind "nav". */
    property string navTarget: ""
    /** Seg values to cycle; defaults to the Schema entry's option values. */
    property var navVals: undefined
    /** Overrides for rows that do not read or write through Store. */
    property var navGet: null
    property var navSet: null
    /** Scrub step; defaults to the first `bump()`-carrying control under `bumpHost`. */
    property var navBump: null
    property Item bumpHost: null

    readonly property var entry: nav.settingId.length > 0 ? Schema.settings[nav.settingId] : null

    /** `seg`, `toggle`, `scrub` or `nav` — what the arrow keys and Return do here. */
    readonly property string kind: {
        if (nav.navKind.length > 0)
            return nav.navKind;
        if (nav.entry && nav.entry.control)
            return nav.entry.control;
        return nav.navTarget.length > 0 ? "nav" : "";
    }

    /** The seg row's cycle order, in the same order the segments are drawn. */
    readonly property var vals: {
        if (nav.navVals !== undefined)
            return nav.navVals;
        if (nav.entry && nav.entry.options)
            return nav.entry.options.map(function (o) { return o.value; });
        return [];
    }

    function get() {
        return nav.navGet ? nav.navGet() : Store.get(nav.settingId);
    }

    function set(v) {
        if (nav.navSet)
            nav.navSet(v);
        else
            Store.set(nav.settingId, v);
    }

    /**
     * Steps a scrub row one increment. Rows whose scrub lives in their own
     * control slot need say nothing — the slot is searched once and cached —
     * while the monitor card, whose pickers step through the card itself,
     * hands over `navBump`.
     */
    function bump(d) {
        if (nav.navBump) {
            nav.navBump(d);
            return;
        }
        if (!nav.bumpItem)
            nav.bumpItem = nav.findBumpable(nav.bumpHost ? nav.bumpHost : nav.item);
        if (nav.bumpItem)
            nav.bumpItem.bump(d);
    }

    property var bumpItem: null

    function findBumpable(host) {
        if (!host)
            return null;
        for (var i = 0; i < host.children.length; i++) {
            var c = host.children[i];
            if (c && typeof c.bump === "function")
                return c;
            var deep = nav.findBumpable(c);
            if (deep)
                return deep;
        }
        return null;
    }

    /**
     * A claim counts while the row is on screen and actually describes a
     * control: an unknown `settingId` (or a row that names neither a kind nor a
     * target) stays out of navigation rather than crashing the arrow keys.
     */
    readonly property bool claimed: nav.surface !== null && nav.item !== null && nav.item.visible && nav.kind.length > 0

    /** The surface this claim is currently lodged with, so it can be withdrawn. */
    property var lodged: null

    function sync() {
        var want = nav.claimed ? nav.surface : null;
        if (nav.lodged === want)
            return;
        if (nav.lodged)
            nav.lodged.unregisterNav(nav);
        nav.lodged = want;
        if (want)
            want.registerNav(nav);
    }

    onClaimedChanged: nav.sync()
    onSurfaceChanged: nav.sync()

    Component.onCompleted: {
        if (nav.settingId.length > 0 && !nav.entry)
            console.warn("SettingsNav: unknown settingId '" + nav.settingId + "'");
        nav.sync();
    }

    Component.onDestruction: {
        if (nav.lodged)
            nav.lodged.unregisterNav(nav);
        nav.lodged = null;
    }
}
