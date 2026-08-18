pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * SESSION sub-surface: what the machine does while you are not using it.
 *
 * Grown out of the old Idle / Lock page, which held the three hypridle timeouts
 * and nothing else. Focus comes first — do-not-disturb, keep-awake and game
 * mode, the three flags the mixer's chips flip — because they are the ones that
 * suspend everything below them; the mixer keeps its chips as pointers, but the
 * settings are named and captioned here. Then the two idle timeouts, held in
 * minutes (0 = off): auto-lock runs the lock script and screen-off blanks the
 * display through DPMS. Both are undone by touching the mouse.
 *
 * Suspend is not, so it does not sit with them. It is below the fold on its own
 * with danger styling and a two-step confirm (Schema marks it `danger`): the
 * first tap on a non-Off timeout arms the row and says so, and only a second
 * tap on the SAME timeout within three seconds writes it. Off commits at once —
 * turning suspend off has never cost anyone anything.
 *
 * Every row reads and writes through Store, which for the `idle` backend
 * regenerates the whole hypridle.conf from the current values and restarts
 * hypridle, so a change lands without a hand edit and this surface carries no
 * write plumbing of its own. Labels, captions and option strips come from
 * Schema. Reached from the settings index and morphs back to it via the back
 * chevron in the header strip, popping the settings stack.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property var dndEntry: Schema.settings.dnd
    readonly property var awakeEntry: Schema.settings.keepAwake
    readonly property var gameEntry: Schema.settings.gameMode
    readonly property var lockEntry: Schema.settings.idleLockMin
    readonly property var screenEntry: Schema.settings.idleScreenOffMin
    readonly property var suspendEntry: Schema.settings.idleSuspendMin

    /** The two-step gate guarding Suspend; keyed by the timeout being asked about. */
    property SettingsConfirm suspendGate: SettingsConfirm {}

    /** The timeout currently armed, or `undefined` when the row is at rest. */
    readonly property var suspendArmed: {
        var a = root.suspendGate.armed;
        return a.indexOf("suspend:") === 0 ? parseInt(a.slice(8), 10) : undefined;
    }

    /**
     * One tap on the Suspend strip. Off and the value already stored commit or
     * cancel outright — neither of them puts the machine to sleep — and anything
     * else has to be asked twice.
     */
    function requestSuspend(v) {
        if (v === Store.get("idleSuspendMin")) {
            root.suspendGate.clear();
            return;
        }
        if (v === 0) {
            root.suspendGate.clear();
            Store.set("idleSuspendMin", 0);
            return;
        }
        if (root.suspendGate.request("suspend:" + v))
            Store.set("idleSuspendMin", v);
    }

    /** Nothing stays armed off screen: closing the page is an answer of "no". */
    onActiveChanged: {
        root.suspendGate.clear();
        if (!active) {
            focusRowItem = null;
            kbIndex = -1;
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
            glyph: "\uf023"
            title: "SESSION"
            showBack: true
        }

        SettingsGroup { id: focusGrp; s: root.s; hPad: 12 * root.s; title: "Focus"; open: true

        SettingsRow {
            id: dndRow
            surface: root
            settingId: "dnd"
            name: root.dndEntry.label
            sub: root.dndEntry.caption
            captionOnFocus: true
            LinkToggle {
                s: root.s
                on: Store.get("dnd")
                onToggled: Store.set("dnd", !Store.get("dnd"))
            }
        }

        SettingsRow {
            id: awakeRow
            surface: root
            settingId: "keepAwake"
            name: root.awakeEntry.label
            sub: root.awakeEntry.caption
            captionOnFocus: true
            LinkToggle {
                s: root.s
                on: Store.get("keepAwake")
                onToggled: Store.set("keepAwake", !Store.get("keepAwake"))
            }
        }

        /**
         * Game mode is a flag with a script behind it: GameMode watches
         * `Flags.gameMode` and runs the strip, snapshotting and restoring the
         * other focus flags itself. So this stays a plain Store write — the
         * side effect belongs to the singleton, not to the row.
         */
        SettingsRow {
            id: gameRow
            surface: root
            settingId: "gameMode"
            name: root.gameEntry.label
            sub: root.gameEntry.caption
            captionOnFocus: true
            last: true
            LinkToggle {
                s: root.s
                on: Store.get("gameMode")
                onToggled: Store.set("gameMode", !Store.get("gameMode"))
            }
        }

        }

        SettingsGroup { id: idleGrp; s: root.s; hPad: 12 * root.s; title: "Idle"; open: true

        SettingsRow {
            id: lockRow
            surface: root
            settingId: "idleLockMin"
            name: root.lockEntry.label
            sub: root.lockEntry.caption
            captionOnFocus: true

            SettingsSeg {
                s: root.s
                options: root.lockEntry.options
                value: Store.get("idleLockMin")
                onPicked: (v) => Store.set("idleLockMin", v)
            }
        }

        SettingsRow {
            id: screenRow
            surface: root
            settingId: "idleScreenOffMin"
            name: root.screenEntry.label
            sub: root.screenEntry.caption
            captionOnFocus: true
            last: true

            SettingsSeg {
                s: root.s
                options: root.screenEntry.options
                value: Store.get("idleScreenOffMin")
                onPicked: (v) => Store.set("idleScreenOffMin", v)
            }
        }

        }

        Item { width: 1; height: 14 * root.s }

        /** The fold: everything above it is undone by moving the mouse. */
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        /**
         * `navSet` routes the keyboard through the same gate as the mouse. The
         * seg cycles off the STORED value, so while the row is armed the arrow
         * key keeps landing on the armed option rather than walking past it —
         * two presses arm and confirm, exactly like two taps.
         */
        SettingsRow {
            id: suspendRow
            surface: root
            settingId: "idleSuspendMin"
            navSet: (v) => root.requestSuspend(v)
            name: root.suspendEntry.label
            sub: root.suspendArmed !== undefined ? "Tap again to confirm" : root.suspendEntry.caption
            subColor: (root.suspendArmed !== undefined && root.suspendEntry.danger) ? Theme.vermLit : Theme.faint
            captionOnFocus: root.suspendArmed === undefined
            last: true

            SettingsSeg {
                s: root.s
                options: root.suspendEntry.options
                value: Store.get("idleSuspendMin")
                armedValue: root.suspendArmed
                onPicked: (v) => root.requestSuspend(v)
            }
        }

        Text {
            topPadding: 12 * root.s
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            width: parent.width
            text: "Keep awake pauses every idle timeout while it is on."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 10 * root.s }
    }
}
