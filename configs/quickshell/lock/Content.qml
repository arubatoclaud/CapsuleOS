pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "Singletons"

Item {
    id: content
    property real s: 1
    property var auth: null
    property bool isMain: true

    readonly property bool authenticating: auth ? auth.authenticating : false
    property bool showError: false

    /**
     * Password visibility toggle for the capsule eye. Masked renders no text at
     * all: the TextInput itself draws transparent and a plain bullet row stands in
     * for the characters, the way Sonoma's field does. Reveal swaps the bullets
     * for the real string. Reset on every auth attempt so a retry never leaks
     * state.
     */
    property bool reveal: false

    Connections {
        target: content.auth
        enabled: content.auth !== null
        function onFailed() {
            content.showError = true;
            content.reveal = false;
            input.text = "";
            shake.restart();
        }
        function onSucceeded() {
            content.showError = false;
            content.reveal = false;
            input.text = "";
        }
    }

    readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property string dateText: {
        var d = sysClock.date;
        return weekdays[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
    }

    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return controllable ? controllable : list[0];
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying

    readonly property string trackTitle: {
        if (!player)
            return "";
        return player.trackTitle ? player.trackTitle : "";
    }
    readonly property string trackArtist: {
        if (!player)
            return "";
        if (player.trackArtists && player.trackArtists.length > 0)
            return player.trackArtists;
        return player.trackArtist ? player.trackArtist : "";
    }
    readonly property string artUrl: {
        if (!player)
            return "";
        return player.trackArtUrl ? player.trackArtUrl : "";
    }
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real progress: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0

    function fmtTime(sec) {
        var m = Math.floor(sec / 60);
        var ss = Math.floor(sec % 60);
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    readonly property string metaLine: {
        var t = lengthSec > 0 ? fmtTime(positionSec) + " / " + fmtTime(lengthSec) : "";
        if (trackArtist.length > 0 && t.length > 0)
            return trackArtist + " · " + t;
        return trackArtist.length > 0 ? trackArtist : t;
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 1000
        running: content.playing && content.isMain
        repeat: true
        onTriggered: if (content.player) content.player.positionChanged()
    }

    /**
     * Sonoma's clock: hairline, huge, centred on the upper tenth of the screen,
     * with the date reading as one quiet line directly under it. The drop shadow
     * stays — at Font.Thin over a bright patch of wallpaper the strokes vanish
     * without it.
     */
    Text {
        id: clockText
        visible: content.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.10
        color: Theme.bright
        font.family: Theme.font
        font.weight: Font.Thin
        font.pixelSize: 96 * content.s
        /** Qt reads "h" as 24h unless the same format holds AP, and the AM/PM sits in its own label here, so the 12h hour is built by hand. */
        text: {
            var d = sysClock.date;
            if (!Flags.time12h)
                return Qt.formatDateTime(d, "HH:mm");
            var h = d.getHours() % 12;
            if (h === 0)
                h = 12;
            var m = d.getMinutes();
            return h + ":" + (m < 10 ? "0" : "") + m;
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.9
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }

    Text {
        visible: content.isMain && Flags.time12h
        anchors.left: clockText.right
        anchors.leftMargin: 10 * content.s
        anchors.baseline: clockText.baseline
        color: Theme.bright
        opacity: 0.5
        font.family: Theme.font
        font.weight: Font.Light
        font.pixelSize: 26 * content.s
        text: Qt.formatDateTime(sysClock.date, "AP")
    }

    Text {
        visible: content.isMain
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockText.bottom
        anchors.topMargin: 4 * content.s
        text: content.dateText
        color: Theme.cream
        font.family: Theme.font
        font.weight: Font.Medium
        font.pixelSize: 14 * content.s
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }

    Column {
        visible: content.isMain && content.hasPlayer
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: parent.width * 0.045
        /** Sits on the same baseline as the auth capsule so the two bottom clusters read as one row. */
        anchors.bottomMargin: parent.height * 0.12
        spacing: 9 * content.s

        Row {
            spacing: 12 * content.s

            Rectangle {
                width: 48 * content.s
                height: 48 * content.s
                radius: 10 * content.s
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: "#1a100c"
                Image {
                    id: coverImg
                    anchors.fill: parent
                    visible: content.artUrl.length > 0
                    source: content.artUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    cache: false
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }
                Item {
                    id: coverMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle {
                        anchors.fill: parent
                        radius: 10 * content.s
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * content.s

                Text {
                    text: content.trackTitle.length > 0 ? content.trackTitle : "Unknown"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * content.s
                    font.weight: 600
                    elide: Text.ElideRight
                    width: 140 * content.s
                }
                Text {
                    visible: content.metaLine.length > 0
                    text: content.metaLine
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10 * content.s
                    font.weight: 500
                    elide: Text.ElideRight
                    width: 140 * content.s
                }
            }
        }

        Item {
            width: 200 * content.s
            height: 2

            Rectangle {
                anchors.fill: parent
                radius: 1
                color: Theme.trackBg
            }
            Rectangle {
                id: threadFill
                width: parent.width * content.progress
                height: parent.height
                radius: 1
                color: Theme.mark
            }
            Rectangle {
                x: Math.min(parent.width - width, Math.max(0, threadFill.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 5 * content.s
                height: 5 * content.s
                radius: width / 2
                color: Theme.cream
            }
        }
    }

    /**
     * The account disc above the field. `~/.face` is the freedesktop convention
     * the display managers already read, so the lock picks up whatever avatar the
     * user set once; with no file (or an unreadable one) the disc falls back to
     * the first letter of the login name rather than an empty hole.
     *
     * A radius on the enclosing Rectangle would not clip the photo — Qt's clip is
     * rectangular — so the crop is a MultiEffect mask, the same recipe the cover
     * art above uses.
     */
    Rectangle {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: capsule.top
        anchors.bottomMargin: 18 * content.s
        width: 72 * content.s
        height: width
        radius: width / 2
        color: Theme.fieldBg
        border.width: 1
        border.color: Theme.hair
        antialiasing: true
        opacity: content.isMain ? (content.authenticating ? 0.6 : 1) : 0

        Image {
            id: face
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.face"
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
            visible: face.status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: faceMask
            }
        }

        Item {
            id: faceMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                antialiasing: true
            }
        }

        Text {
            anchors.centerIn: parent
            visible: face.status !== Image.Ready
            text: {
                var u = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "";
                return u.length > 0 ? u.charAt(0).toUpperCase() : "?";
            }
            color: Theme.cream
            font.family: Theme.font
            font.weight: Font.Medium
            font.pixelSize: 30 * content.s
        }
    }

    Rectangle {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        width: 300 * content.s
        height: 44 * content.s
        radius: height / 2
        color: Theme.fieldBg
        border.width: 1
        border.color: Theme.fieldBorder
        antialiasing: true
        opacity: content.isMain ? (content.authenticating ? 0.6 : 1) : 0

        transform: Translate { id: capsuleShift }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: capsuleShift; property: "x"; to: 9 * content.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: -9 * content.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: 6 * content.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: -6 * content.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: 0; duration: 50 }
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 20 * content.s
            anchors.rightMargin: 42 * content.s
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Normal
            color: content.reveal ? Theme.bright : "transparent"
            font.family: Theme.font
            font.pixelSize: 14 * content.s
            font.letterSpacing: 1 * content.s
            clip: true
            focus: true
            enabled: !content.authenticating
            onTextChanged: {
                if (text.length > 0)
                    content.showError = false;
                if (Pw.text !== text)
                    Pw.text = text;
            }

            Connections {
                target: Pw
                function onTextChanged() {
                    if (input.text !== Pw.text)
                        input.text = Pw.text;
                }
            }
            onAccepted: {
                if (content.auth && text.length > 0)
                    content.auth.submit(text);
            }

            cursorDelegate: Rectangle {
                visible: content.reveal && input.text.length > 0
                width: 2 * content.s
                height: input.cursorRectangle.height
                color: Theme.bright
                SequentialAnimation on opacity {
                    running: input.activeFocus
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: 550 }
                    NumberAnimation { to: 1; duration: 0 }
                    PauseAnimation { duration: 550 }
                }
            }
        }

        /**
         * Placeholder and error share the one label: an empty field reads "Enter
         * Password", and a rejected attempt (which clears the field) turns the
         * same line into whatever PAM said.
         */
        Text {
            anchors.centerIn: parent
            width: input.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: input.text.length === 0
            text: {
                if (!content.showError)
                    return "Enter Password";
                var pamMsg = content.auth ? content.auth.lastError : "";
                return pamMsg.length > 0 ? pamMsg : "Wrong password";
            }
            color: content.showError ? Theme.error : Qt.alpha(Theme.cream, 0.6)
            font.family: Theme.font
            font.pixelSize: 13 * content.s
            font.weight: Font.Medium
        }

        /**
         * Plain bullets stand in for the characters while the field is masked —
         * the TextInput itself draws transparent, so this row is all the user
         * sees until the eye reveals the real string.
         */
        Text {
            anchors.centerIn: parent
            width: input.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: !content.reveal && input.text.length > 0
            text: "•".repeat(input.text.length)
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 15 * content.s
            font.letterSpacing: 3 * content.s
        }

        GlyphIcon {
            id: eye
            anchors.right: parent.right
            anchors.rightMargin: 14 * content.s
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * content.s
            height: 18 * content.s
            name: content.reveal ? "eye-off" : "eye"
            color: eyeArea.containsMouse ? Theme.bright : Qt.alpha(Theme.cream, 0.55)
            stroke: 1.7

            MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -6 * content.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: content.reveal = !content.reveal
            }
        }
    }
}
