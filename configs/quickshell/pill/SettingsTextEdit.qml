pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * Free-text control for a settings row: a right-aligned value that swaps for an
 * inline field when tapped, commits on Return and cancels on Escape.
 *
 * Two settings are plain text — the wallpaper folder and the weather town — and
 * both already had exactly this editor drawn by hand in the surface that owns
 * them (Wallpaper's header caption, the calendar's town line). Neither of those
 * moves; this is the same interaction on the settings side, so a folder typed
 * in one place reads the same in the other.
 *
 * The field releases focus the moment it commits or cancels, the way
 * Appearance's hex field already does — a settings surface routes arrow keys
 * and Return to its row registry, and a field that kept focus would keep
 * swallowing them.
 */
Item {
    id: edit

    property real s: 1
    /** The stored value. Shown when idle, and what the field is seeded from. */
    property string value: ""
    /** Stand-in shown when `value` is empty: what the empty string resolves to. */
    property string placeholder: ""
    property real fieldWidth: 176 * edit.s

    signal committed(string text)

    property bool editing: false

    width: edit.fieldWidth
    height: 20 * edit.s

    function begin() {
        field.text = edit.value;
        edit.editing = true;
        field.forceActiveFocus();
        field.selectAll();
    }

    function commit() {
        var t = field.text.trim();
        edit.editing = false;
        field.focus = false;
        edit.committed(t);
    }

    function cancel() {
        edit.editing = false;
        field.focus = false;
    }

    Text {
        id: shown
        anchors.fill: parent
        visible: !edit.editing
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: edit.value.length > 0 ? edit.value : edit.placeholder
        color: shownArea.containsMouse ? Theme.cream : (edit.value.length > 0 ? Theme.subtle : Theme.faint)
        font.family: Theme.font
        font.pixelSize: 10.5 * edit.s
        font.weight: Font.Medium
        elide: Text.ElideMiddle
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        id: shownArea
        anchors.fill: parent
        anchors.margins: -4 * edit.s
        visible: !edit.editing
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: edit.begin()
    }

    TextField {
        id: field
        anchors.fill: parent
        visible: edit.editing
        enabled: edit.editing
        background: null
        padding: 0
        horizontalAlignment: Text.AlignRight
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 10.5 * edit.s
        font.weight: Font.Medium
        placeholderText: edit.placeholder
        placeholderTextColor: Theme.faint
        selectByMouse: true
        selectionColor: Theme.markDeep

        onAccepted: edit.commit()
        Keys.onEscapePressed: edit.cancel()
        onActiveFocusChanged: if (!activeFocus && edit.editing) edit.cancel()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.topMargin: 2 * edit.s
        height: 1
        color: Theme.faint
        opacity: edit.editing ? 0.7 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }
}
