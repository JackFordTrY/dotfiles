import QtQuick
import qs.config
import qs.components

// A quick-settings tile. The icon square switches the thing on and off; the rest of the tile
// picks its page.
Item {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool on
    property bool selected

    signal toggled
    signal picked

    implicitHeight: 50

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.selected ? Theme.active : pickArea.containsMouse ? Theme.hover : Theme.raised
        border.width: 1
        border.color: root.selected || pickArea.containsMouse ? Theme.purpleGlowStrong : Theme.purpleGlow

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: pickArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.picked()
    }

    Rectangle {
        id: toggle

        x: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 10
        color: root.on ? Qt.alpha(Theme.purple0, toggleArea.containsMouse ? 0.55 : 0.38) : toggleArea.containsMouse ? Theme.surface5 : Theme.surface4

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration
                easing.type: Easing.OutCubic
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            fill: root.on ? 1 : 0
            glow: root.on ? 0.9 : 0
            color: root.on ? Theme.text1 : Theme.textMuted
        }

        MouseArea {
            id: toggleArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: root.toggled()
        }
    }

    Column {
        anchors.left: toggle.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.title
            color: pickArea.containsMouse && !root.selected ? "white" : Theme.text1
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.subtitle
            color: Theme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
