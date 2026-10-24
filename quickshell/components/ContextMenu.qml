pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// A small menu of `entries` ({ icon, text }) in the tray menus' style, for the bar's own right
// click menus. Picking one emits `chosen` with its index; the opener closes it then, or when it
// stops being visible (a click elsewhere).
PopupWindow {
    id: root

    property var entries: []

    signal chosen(int index)

    color: "transparent"
    grabFocus: true
    implicitWidth: 230
    implicitHeight: column.implicitHeight + 12

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.popupBackground
        border.width: 1
        border.color: Theme.purpleGlowStrong

        Column {
            id: column

            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: root.entries

                Rectangle {
                    id: entry

                    required property var modelData
                    required property int index

                    width: column.width
                    height: 30
                    radius: 8
                    color: area.containsMouse ? Theme.hover : "transparent"

                    MaterialIcon {
                        id: icon

                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.icon
                        size: 18
                        fill: area.containsMouse ? 1 : 0
                        color: area.containsMouse ? Theme.accent : Theme.text2
                    }

                    StyledText {
                        anchors.left: icon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.text
                        color: area.containsMouse ? Theme.text1 : Theme.text2
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chosen(entry.index)
                    }
                }
            }
        }
    }
}
