pragma ComponentBehavior: Bound

import QtQuick

/**
 * Two-step confirm gate for a settings control that cannot be undone.
 *
 * The shell already asks twice before it throws something away — the launcher's
 * AppImage trash and the recorder's clip delete both arm on the first click and
 * act on the second, and Wifi/Bluetooth fold out an inline confirm row rather
 * than disconnecting on the tap that opened it. This is that idiom with a clock
 * on it, for the two settings whose damage is not a deleted file but a desktop
 * that has rearranged itself or a machine that has gone to sleep: Session's
 * Suspend-after and Display's Set-as-main.
 *
 * `request(key)` is the whole API. The first call for a key arms it and returns
 * false — the caller draws "Tap again to confirm" — and a second call with the
 * SAME key inside `holdMs` returns true, meaning go ahead. A different key
 * re-arms rather than confirming, so moving from "15 min" to "30 min" while
 * armed asks about 30 rather than committing 15. The window disarms on its own,
 * so an armed control left alone is a control that was never touched.
 *
 * The key is a string because that is what makes a seg work: the value being
 * confirmed is part of the identity of the question.
 */
QtObject {
    id: gate

    /** The key currently armed, or "" when nothing is. */
    property string armed: ""
    /** How long an armed key stays armed. */
    property int holdMs: 3000

    readonly property bool active: gate.armed.length > 0

    /** True when this call is the confirmation; false when it armed instead. */
    function request(key) {
        if (gate.armed === key) {
            gate.clear();
            return true;
        }
        gate.armed = key;
        holdTimer.restart();
        return false;
    }

    /** Drop the arm. Pages call this when they close, so nothing stays armed off screen. */
    function clear() {
        holdTimer.stop();
        gate.armed = "";
    }

    property Timer _hold: Timer {
        id: holdTimer
        interval: gate.holdMs
        repeat: false
        onTriggered: gate.armed = ""
    }
}
