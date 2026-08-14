import QtQuick
import QtQuick.Window
import QtQuick.Effects

Item {
    id: root

    readonly property bool hasScreens: (typeof primaryScreen !== "undefined")
    readonly property bool onPrimary: !hasScreens || (primaryScreen === true)

    readonly property bool hasSddm: typeof sddm !== "undefined"
    readonly property bool hasConfig: typeof config !== "undefined"

    function cfg(key, fallback) {
        if (!hasConfig)
            return fallback
        var v = config[key]
        return (v === undefined || v === null || ("" + v).length === 0) ? fallback : v
    }

    readonly property real userScale: parseFloat(cfg("scale", "1.0")) || 1.0
    readonly property real s: (root.height > 0 ? root.height / 1080 : 1) * userScale

    // Night palette (PillOS reskin, Task 4)
    readonly property color accent: cfg("accent", "#ffb454")
    readonly property color accentDeep: "#ff9838"
    readonly property color accentGlow: Qt.rgba(255 / 255, 180 / 255, 84 / 255, 0.9)
    readonly property color surface0: "#0a0e16"
    readonly property color surface1: "#10151f"
    readonly property color surface2: "#161c28"
    readonly property color borderCol: "#263042"
    readonly property color textDim: "#a4aebc"
    readonly property color textBright: "#d5dce6"
    readonly property color brightWhite: "#f2f6fb"
    readonly property color hairStrong: Qt.rgba(38 / 255, 48 / 255, 66 / 255, 0.75)

    property int currentUserIndex: hasSddm ? Math.max(0, userProbe.lastIndex) : 0
    property int currentSessionIndex: hasSddm ? Math.max(0, sessionProbe.lastIndex) : 0

    readonly property string currentUserName: {
        if (!hasSddm)
            return "user"
        var n = userProbe.fieldAt(currentUserIndex, "name")
        return n.length > 0 ? n : "user"
    }
    readonly property url currentUserIcon: hasSddm ? userProbe.iconAt(currentUserIndex) : ""

    readonly property string currentSessionName: {
        if (!hasSddm)
            return "Hyprland"
        var n = sessionProbe.fieldAt(currentSessionIndex, "name")
        return n.length > 0 ? n : "Session"
    }

    function submit() {
        if (passwordField.text.length === 0) {
            passwordField.forceActiveFocus()
            return
        }
        errorRow.shown = false
        if (hasSddm)
            sddm.login(currentUserName, passwordField.text, currentSessionIndex)
    }

    function clearPassword() {
        passwordField.text = ""
        passwordField.forceActiveFocus()
    }

    ModelProbe {
        id: userProbe
        sourceModel: hasSddm ? userModel : null
        lastIndex: hasSddm ? userModel.lastIndex : 0
    }

    ModelProbe {
        id: sessionProbe
        sourceModel: hasSddm ? sessionModel : null
        lastIndex: hasSddm ? sessionModel.lastIndex : 0
    }

    component ModelProbe: Item {
        id: probe
        property var sourceModel: null
        property int lastIndex: 0
        readonly property int count: rep.count
        property int version: 0
        property var rows: ({})

        function record(row, field, value) {
            probe.rows[row + ":" + field] = (value === undefined || value === null) ? "" : value
            probe.version++
        }
        function fieldAt(row, field) {
            void probe.version
            var v = probe.rows[row + ":" + field]
            return (v === undefined || v === null) ? "" : "" + v
        }
        function iconAt(row) {
            void probe.version
            var v = probe.rows[row + ":icon"]
            return (v === undefined || v === null) ? "" : v
        }

        Repeater {
            id: rep
            model: probe.sourceModel
            delegate: Item {
                required property int index
                required property var model
                Component.onCompleted: {
                    probe.record(index, "name", model.name)
                    probe.record(index, "realName", model.realName)
                    probe.record(index, "icon", model.icon)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -5000
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onContainsMouseChanged: {
            if (root.onPrimary && containsMouse) {
                var w = root.Window.window
                if (w)
                    w.requestActivate()
                if (!passwordField.activeFocus)
                    passwordField.forceActiveFocus()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.surface0
        z: -2000
    }

    Item {
        id: stage
        anchors.fill: parent
        clip: true

    Image {
        id: bgImage
        anchors.fill: parent
        source: Qt.resolvedUrl(root.cfg("background", "assets/bg_poster.jpg"))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
        z: -1001
    }

    MultiEffect {
        anchors.fill: bgImage
        source: bgImage
        z: -1000
        blurEnabled: true
        blur: 0.6
        blurMax: 48
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        z: -900
        color: root.surface0
        opacity: 0.55
    }

    Item {
        id: topCenter
        z: 10
        visible: root.onPrimary
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.1
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.brightWhite
            font.family: "Inter"
            font.weight: Font.Thin
            font.pixelSize: 96 * root.s
            font.letterSpacing: 1 * root.s
            text: clockTimer.timeText
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clock.bottom
            anchors.topMargin: 8 * root.s
            color: root.textDim
            font.family: "Inter"
            font.weight: 500
            font.pixelSize: 15 * root.s
            font.letterSpacing: 1.5 * root.s
            text: clockTimer.dateText
        }
    }

    Timer {
        id: clockTimer
        property string timeText: ""
        property string dateText: ""
        readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var hh = ("0" + d.getHours()).slice(-2)
            var mm = ("0" + d.getMinutes()).slice(-2)
            timeText = hh + ":" + mm
            dateText = weekdays[d.getDay()] + " · " + months[d.getMonth()] + " " + d.getDate()
        }
    }

    Column {
        id: authColumn
        z: 10
        visible: root.onPrimary
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.86 - height
        spacing: 18 * root.s

        Item {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 68 * root.s
            height: 68 * root.s

            Rectangle {
                id: avatarRing
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(242 / 255, 246 / 255, 251 / 255, 0.12)
                border.width: 1.5 * root.s
                border.color: root.hairStrong
            }

            Image {
                id: avatarImg
                anchors.fill: parent
                anchors.margins: 3 * root.s
                fillMode: Image.PreserveAspectCrop
                source: root.currentUserIcon
                visible: false
                smooth: true
            }

            Item {
                id: avatarMask
                anchors.fill: avatarImg
                layer.enabled: true
                layer.smooth: true
                visible: false
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: avatarImg
                source: avatarImg
                maskEnabled: true
                maskSource: avatarMask
                visible: avatarImg.status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: avatarImg.status !== Image.Ready
                text: root.currentUserName.length > 0 ? root.currentUserName.charAt(0).toUpperCase() : "?"
                color: root.brightWhite
                font.family: "Inter"
                font.weight: 500
                font.pixelSize: 26 * root.s
            }
        }

        Row {
            id: userChip
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * root.s

            Text {
                id: userNameText
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentUserName
                opacity: userHover.hovered ? 0.85 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                color: root.textBright
                font.family: "Inter"
                font.weight: 500
                font.pixelSize: 16 * root.s
                font.letterSpacing: 0.2 * root.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.hasSddm || userProbe.count > 1
                text: "⌄"
                color: root.textDim
                font.family: "Inter"
                font.pixelSize: 12 * root.s
                rotation: userPopup.opened ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            HoverHandler {
                id: userHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                enabled: !root.hasSddm || userProbe.count > 1
                onTapped: userPopup.toggle()
            }
        }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320 * root.s
            height: 50 * root.s
            radius: height / 2
            color: Qt.rgba(242 / 255, 246 / 255, 251 / 255, 0.16)
            border.width: 1
            border.color: passwordField.activeFocus
                ? root.accent
                : Qt.rgba(242 / 255, 246 / 255, 251 / 255, 0.25)
            Behavior on border.color { ColorAnimation { duration: 150 } }

            property real shakeOffset: 0
            transform: Translate { x: pill.shakeOffset }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: pill; property: "shakeOffset"; to: 9 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: -9 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: 6 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: -6 * root.s; duration: 50 }
                NumberAnimation { target: pill; property: "shakeOffset"; to: 0; duration: 50 }
            }

            Row {
                id: pillRow
                anchors.fill: parent
                anchors.leftMargin: 18 * root.s
                anchors.rightMargin: 10 * root.s
                spacing: 10 * root.s

                TextInput {
                    id: passwordField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 * root.s - parent.spacing
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.textBright
                    font.family: "Inter"
                    font.pixelSize: 14 * root.s
                    selectByMouse: true
                    clip: true
                    cursorVisible: false

                    cursorDelegate: Rectangle {
                        width: 2 * root.s
                        height: 14 * root.s
                        color: root.accent
                        SequentialAnimation on opacity {
                            running: passwordField.activeFocus
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 0; }
                            PauseAnimation { duration: 550 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 550 }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: "Password"
                        color: root.textDim
                        font: passwordField.font
                        visible: passwordField.text.length === 0 && !passwordField.activeFocus
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.submit()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            userPopup.close()
                            sessionPopup.close()
                            root.clearPassword()
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: submitBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * root.s
                    height: 30 * root.s
                    radius: width / 2
                    scale: submitArea.pressed ? 0.92 : (submitArea.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.accent }
                        GradientStop { position: 1.0; color: root.accentDeep }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: root.surface0
                        font.family: "Inter"
                        font.pixelSize: 15 * root.s
                    }

                    MouseArea {
                        id: submitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }

        Text {
            id: errorRow
            property bool shown: false
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Login failed"
            color: root.accent
            font.family: "Inter"
            font.pixelSize: 12 * root.s
            font.letterSpacing: 0.5 * root.s
            opacity: shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    component ActionLabel: Item {
        id: actionRoot
        property string label: ""
        property string glyph: ""
        signal activated
        implicitWidth: actionContent.implicitWidth
        implicitHeight: 26 * root.s

        Row {
            id: actionContent
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s

            Text {
                id: actionText
                anchors.verticalCenter: parent.verticalCenter
                text: actionRoot.label
                color: root.textDim
                opacity: actionArea.containsMouse ? 1.0 : 0.88
                font.family: "Inter"
                font.pixelSize: 11 * root.s
                font.letterSpacing: 1.4 * root.s
                font.capitalization: Font.AllUppercase
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: actionRoot.glyph.length > 0
                text: actionRoot.glyph
                color: root.textDim
                opacity: 0.7
                font.family: "Inter"
                font.pixelSize: 10 * root.s
            }
        }

        Rectangle {
            anchors.top: actionContent.bottom
            anchors.topMargin: 3 * root.s
            anchors.left: actionContent.left
            height: 1.5 * root.s
            radius: height / 2
            color: root.accent
            width: actionArea.containsMouse ? actionText.implicitWidth : 0
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.activated()
        }
    }

    Item {
        z: 10
        visible: root.onPrimary
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: parent.width * 0.06
        anchors.rightMargin: parent.width * 0.06
        anchors.bottomMargin: 22 * root.s
        height: 26 * root.s

        ActionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            label: root.currentSessionName
            glyph: "⌄"
            onActivated: sessionPopup.toggle()
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24 * root.s

            ActionLabel {
                anchors.verticalCenter: parent.verticalCenter
                label: "Restart"
                onActivated: if (root.hasSddm) sddm.reboot()
            }
            ActionLabel {
                anchors.verticalCenter: parent.verticalCenter
                label: "Shut Down"
                onActivated: if (root.hasSddm) sddm.powerOff()
            }
        }
    }

    component SelectPanel: Rectangle {
        id: panel
        property var entries: []
        property int activeIndex: 0
        signal picked(int index)
        property bool opened: false

        function toggle() {
            opened = !opened
        }
        function open() {
            opened = true
        }
        function close() {
            opened = false
        }

        z: 50
        width: 220 * root.s
        radius: 14 * root.s
        color: Qt.rgba(16 / 255, 21 / 255, 31 / 255, 0.92)
        border.width: 1
        border.color: root.hairStrong
        height: opened ? Math.min(entries.length, 6) * (38 * root.s) + 12 * root.s : 0
        clip: true
        visible: height > 1
        opacity: opened ? 1 : 0

        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Column {
            width: parent.width
            y: 6 * root.s
            Repeater {
                model: panel.entries
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: panel.width
                    height: 38 * root.s
                    color: rowArea.containsMouse ? Qt.rgba(255 / 255, 180 / 255, 84 / 255, 0.16) : "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3 * root.s
                        height: parent.height * 0.5
                        radius: width / 2
                        color: root.accent
                        visible: index === panel.activeIndex
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32 * root.s
                        elide: Text.ElideRight
                        text: modelData
                        color: index === panel.activeIndex ? root.brightWhite : root.textBright
                        font.family: "Inter"
                        font.weight: index === panel.activeIndex ? 600 : 400
                        font.pixelSize: 13 * root.s
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.picked(index)
                            panel.close()
                        }
                    }
                }
            }
        }
    }

    SelectPanel {
        id: userPopup
        x: authColumn.x + authColumn.width / 2 - width / 2
        y: authColumn.y - height - 8 * root.s
        activeIndex: root.currentUserIndex
        entries: {
            var list = []
            if (!root.hasSddm)
                return ["user"]
            for (var i = 0; i < userProbe.count; i++) {
                var rn = userProbe.fieldAt(i, "realName")
                var nm = userProbe.fieldAt(i, "name")
                list.push(rn.length > 0 ? rn : nm)
            }
            return list
        }
        onPicked: function (index) {
            root.currentUserIndex = index
            root.clearPassword()
        }
    }

    SelectPanel {
        id: sessionPopup
        x: parent.width * 0.06
        y: parent.height - height - 54 * root.s
        activeIndex: root.currentSessionIndex
        entries: {
            var list = []
            if (!root.hasSddm)
                return ["Hyprland"]
            for (var i = 0; i < sessionProbe.count; i++) {
                var nm = sessionProbe.fieldAt(i, "name")
                list.push(nm.length > 0 ? nm : "Session " + i)
            }
            return list
        }
        onPicked: function (index) {
            root.currentSessionIndex = index
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 40
        visible: userPopup.opened || sessionPopup.opened
        onClicked: {
            userPopup.close()
            sessionPopup.close()
        }
    }

    }

    Connections {
        target: root.hasSddm ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            errorRow.shown = true
            shakeAnim.restart()
            root.clearPassword()
        }
        function onLoginSucceeded() {
            errorRow.shown = false
        }
    }

    Timer {
        id: focusGrab
        property int ticks: 0
        interval: 350
        running: root.onPrimary
        repeat: true
        onTriggered: {
            var w = root.Window.window
            if (w)
                w.requestActivate()
            passwordField.forceActiveFocus()
            ticks++
            if (ticks >= 5)
                focusGrab.stop()
        }
    }

    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.onPrimary && root.Window.window.active)
                passwordField.forceActiveFocus()
        }
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            userPopup.close()
            sessionPopup.close()
            root.clearPassword()
            event.accepted = true
        }
    }
}
