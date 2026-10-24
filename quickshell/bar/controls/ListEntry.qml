import QtQuick
import qs.config
import qs.components

// One row of a network or device list: an icon, the name, and a status on the right. The row is
// lit while `active` (connected) and its icon pulses while `busy` (connecting).
Item {
    id: root

    property string icon
    property string text
    property string detail
    property color detailColor: Theme.textMuted
    property bool active
    property bool busy
    readonly property bool hovered: mouse.containsMouse
    // Small icons between the name and the status, like a lock
    default property alias badges: badgeRow.data

    signal clicked(int button)

    width: parent ? parent.width : 0
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.active ? Theme.active : root.hovered ? Theme.hover : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Theme.purpleGlowStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration
                easing.type: Easing.OutCubic
            }
        }
    }

    MaterialIcon {
        id: icon

        x: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        fill: root.active || root.hovered ? 1 : 0
        glow: root.active ? 0.9 : 0
        color: root.active ? Theme.accent : Theme.text2

        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                icon.opacity = 1

            NumberAnimation {
                to: 0.3
                duration: 500
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 500
                easing.type: Easing.InOutSine
            }
        }
    }

    StyledText {
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: trailing.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.active || root.hovered ? Theme.text1 : Theme.text2
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Row {
            id: badgeRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
        }

        StyledText {
            visible: root.detail !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.detail
            color: root.detailColor
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: event => root.clicked(event.button)
    }
}
