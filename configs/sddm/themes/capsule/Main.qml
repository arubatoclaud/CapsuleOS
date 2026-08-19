import QtQuick
import QtQuick.Effects

/**
 * CapsuleOS login greeter — a standalone port of the lock screen's Content.qml
 * (no Quickshell here, SDDM's greeter is plain Qt). Palette arrives through
 * SDDM's theme config: wallpaper.sh translates colors.json into
 * theme.conf.user on every wallpaper change, so `config.*` below carries the
 * same wallpaper-derived tokens the lock uses; theme.conf holds the static
 * fallbacks.
 */
Rectangle {
    id: root
    color: "#1a100c"

    readonly property real s: height / 1080

    /** Same token derivations as the lock's Theme.qml. */
    readonly property color bright: config.bright || "#f2f6fb"
    readonly property color cream: config.cream || "#d5dce6"
    readonly property color dim: config.dim || "#7d8797"
    readonly property color mark: Qt.darker(config.mark || "#e0762a", 1.18)
    readonly property color errorColor: config.error || "#ff9838"
    readonly property color fieldBg: Qt.alpha(bright, 0.16)
    readonly property color fieldBorder: Qt.alpha(bright, 0.25)
    readonly property color hair: Qt.alpha(cream, 0.13)
    readonly property string uiFont: "Inter"

    readonly property string loginUser: userModel.lastUser || "wannabeartist"

    property bool authenticating: false
    property bool showError: false
    property bool reveal: false

    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false;
            root.showError = true;
            root.reveal = false;
            input.text = "";
            input.forceActiveFocus();
            shake.restart();
        }
        function onLoginSucceeded() {
            root.authenticating = false;
        }
    }

    Image {
        id: wall
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        /**
         * The lock reveals over a blurred grab of the desktop; the greeter has
         * no desktop yet, so the wallpaper itself takes the frost.
         */
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.75
            blurMax: 48
        }
    }

    Timer {
        id: clockTick
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    property var now: new Date()

    readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    Text {
        id: clockText
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.10
        color: root.bright
        font.family: root.uiFont
        font.weight: Font.Thin
        font.pixelSize: 96 * root.s
        text: Qt.formatDateTime(root.now, "HH:mm")
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockText.bottom
        anchors.topMargin: 4 * root.s
        text: root.weekdays[root.now.getDay()] + ", " + root.months[root.now.getMonth()] + " " + root.now.getDate()
        color: root.cream
        font.family: root.uiFont
        font.weight: Font.Medium
        font.pixelSize: 14 * root.s
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }

    Rectangle {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: capsule.top
        anchors.bottomMargin: 18 * root.s
        width: 72 * root.s
        height: width
        radius: width / 2
        color: root.fieldBg
        border.width: 1
        border.color: root.hair
        antialiasing: true
        opacity: root.authenticating ? 0.6 : 1

        Image {
            id: face
            anchors.fill: parent
            source: "current/face"
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
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
            text: root.loginUser.length > 0 ? root.loginUser.charAt(0).toUpperCase() : "?"
            color: root.cream
            font.family: root.uiFont
            font.weight: Font.Medium
            font.pixelSize: 30 * root.s
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: capsule.bottom
        anchors.topMargin: 12 * root.s
        text: root.loginUser
        color: Qt.alpha(root.cream, 0.75)
        font.family: root.uiFont
        font.weight: Font.Medium
        font.pixelSize: 13 * root.s
    }

    Rectangle {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        width: 300 * root.s
        height: 44 * root.s
        radius: height / 2
        color: root.fieldBg
        border.width: 1
        border.color: root.fieldBorder
        antialiasing: true
        opacity: root.authenticating ? 0.6 : 1

        transform: Translate { id: capsuleShift }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: capsuleShift; property: "x"; to: 9 * root.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: -9 * root.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: 6 * root.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: -6 * root.s; duration: 50 }
            NumberAnimation { target: capsuleShift; property: "x"; to: 0; duration: 50 }
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 20 * root.s
            anchors.rightMargin: 42 * root.s
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Normal
            color: root.reveal ? root.bright : "transparent"
            font.family: root.uiFont
            font.pixelSize: 14 * root.s
            font.letterSpacing: 1 * root.s
            clip: true
            focus: true
            enabled: !root.authenticating
            onTextChanged: {
                if (text.length > 0)
                    root.showError = false;
            }
            onAccepted: {
                if (text.length > 0) {
                    root.authenticating = true;
                    sddm.login(root.loginUser, text, sessionModel.lastIndex);
                }
            }

            cursorDelegate: Rectangle {
                visible: root.reveal && input.text.length > 0
                width: 2 * root.s
                height: input.cursorRectangle.height
                color: root.bright
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

        Text {
            anchors.centerIn: parent
            width: input.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: input.text.length === 0
            text: root.showError ? "Wrong password" : "Enter Password"
            color: root.showError ? root.errorColor : Qt.alpha(root.cream, 0.6)
            font.family: root.uiFont
            font.pixelSize: 13 * root.s
            font.weight: Font.Medium
        }

        Text {
            anchors.centerIn: parent
            width: input.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: !root.reveal && input.text.length > 0
            text: "•".repeat(input.text.length)
            color: root.bright
            font.family: root.uiFont
            font.pixelSize: 15 * root.s
            font.letterSpacing: 3 * root.s
        }

        GlyphIcon {
            id: eye
            anchors.right: parent.right
            anchors.rightMargin: 14 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: root.reveal ? "eye-off" : "eye"
            color: eyeArea.containsMouse ? root.bright : Qt.alpha(root.cream, 0.55)
            stroke: 1.7

            MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -6 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reveal = !root.reveal
            }
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
