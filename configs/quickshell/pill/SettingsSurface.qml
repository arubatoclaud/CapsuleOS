pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Shared base for the morphing settings surfaces: the category index and each
 * sub-surface. Carries the keyboard-navigable row registry and the glowing
 * row-soul seam, and morphs back to the parent index when empty space is clicked
 * on a sub-surface. The deriving surface sets `rows`, optionally `backSurface`,
 * and lays out its own content column (header, section labels, SettingsRow lines).
 *
 * Each `rows` entry pairs a row item with its control kind and the backing getter
 * and setter: `seg` cycles a segmented choice (wrapping), `toggle` flips a
 * boolean, `scrub` bumps a numeric scrub through its `bump(dir)`, `nav` morphs
 * to another surface. The host routes arrow keys through `kbMove`,
 * `kbAdjust` and `kbActivate`; hover and clicks route through `reportRowHover`
 * and `activateRow`, keeping `kbIndex` and the seam in sync.
 *
 * Every derived page also gets write-error surfacing for free: a refused or
 * failed `Store.set` used to vanish into an early return, so a value that never
 * landed still looked like it had. The strip below listens to `Store.writeFailed`
 * and shows the message over the foot of the page for four seconds.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    property string backSurface: ""
    signal requestSurface(string name)

    property Item focusRowItem: null
    property int kbIndex: -1
    property var rows: []

    function reportRowHover(item, hovered) {
        if (hovered) {
            focusRowItem = item;
            kbIndex = rowIndexOf(item);
        }
    }
    onActiveChanged: if (!active) {
        focusRowItem = null;
        kbIndex = -1;
    }

    function rowIndexOf(item) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].item === item)
                return i;
        return -1;
    }

    /** Step a seg row's value by `dir`, wrapping at both ends like a mouse click. */
    function segCycle(r, dir) {
        var n = r.vals.length;
        var i = r.vals.indexOf(r.get());
        r.set(r.vals[(((i < 0 ? 0 : i) + dir) % n + n) % n]);
    }

    function kbMove(dir) {
        if (!rows.length)
            return;
        kbIndex = Math.max(0, Math.min(rows.length - 1, (kbIndex < 0 ? 0 : kbIndex + dir)));
        focusRowItem = rows[kbIndex].item;
    }

    function kbAdjust(dir) {
        if (!rows.length)
            return;
        if (kbIndex < 0) {
            kbIndex = 0;
            focusRowItem = rows[0].item;
        }
        var r = rows[kbIndex];
        if (r.kind === "seg")
            segCycle(r, dir);
        else if (r.kind === "toggle")
            r.set(dir > 0);
        else if (r.kind === "scrub")
            r.bump(dir);
    }

    function kbActivate() {
        if (kbIndex < 0)
            return;
        var r = rows[kbIndex];
        if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg")
            segCycle(r, 1);
    }

    /**
     * A click anywhere on a row drives its control: toggles flip and nav rows
     * open their surface. Segmented rows are focus-only on a row-wide click —
     * their own hit areas (the individual segments) remain the way to change
     * the value, so a click on the row's label can't silently step the value.
     */
    function activateRow(item) {
        var idx = rowIndexOf(item);
        if (idx < 0)
            return;
        kbIndex = idx;
        focusRowItem = item;
        var r = rows[idx];
        if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
    }

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    /** Last surfaced write error; cleared four seconds after it arrives. */
    property string errorNote: ""

    Connections {
        target: Store
        function onWriteFailed(id, message) {
            root.errorNote = message;
            errorTimer.restart();
        }
    }

    Timer {
        id: errorTimer
        interval: 4000
        repeat: false
        onTriggered: root.errorNote = ""
    }

    /**
     * Sits over the foot of the page rather than in the content column, so a
     * page's own layout and height never shift when an error appears. The tinted
     * plate is what lets it read as a strip on top of the last row; the text
     * itself carries the same weight, size and colour as the inline notes the
     * pages already use.
     */
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: errorText.implicitHeight + 14 * root.s
        radius: 9 * root.s
        color: Qt.alpha(Theme.tileBg, 0.97)
        border.width: 1
        border.color: Theme.frameBorder
        z: 20
        opacity: root.errorNote.length > 0 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        Text {
            id: errorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10 * root.s
            anchors.rightMargin: 10 * root.s
            text: root.errorNote
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }
    }
}
