import QtQuick
import qs.config

// A small rounded button with an optional icon, for choices and actions inside panels
Rectangle {
    id: root

    property string icon
    property string text
    property bool active
    readonly property alias hovered: area.containsMouse

    signal clicked

    width: row.implicitWidth + 20
    height: 28
    radius: 8
    color: active ? Theme.active : area.containsMouse ? Theme.hover : Theme.raised
    border.width: 1
    border.color: active || area.containsMouse ? Theme.purpleGlowStrong : Theme.purpleGlow

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 16
            fill: root.active ? 1 : 0
            color: root.active ? Theme.accent : Theme.text2
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.active || area.containsMouse ? Theme.text1 : Theme.text2
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
