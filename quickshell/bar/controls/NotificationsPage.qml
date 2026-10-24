pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Every notification so far, newest first; they stay until cleared here. Clicking one follows
// it (the app's own action while the notification is alive, else the app's window); the cross
// removes it. Opening the page marks everything read.
Column {
    id: root

    // Showing on screen
    property bool active

    spacing: 6
    onActiveChanged: {
        if (active)
            Notifs.unread = false;
    }

    Item {
        width: parent.width
        height: label.implicitHeight

        SectionLabel {
            id: label

            text: "NOTIFICATIONS"
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: label.verticalCenter
            spacing: 12

            StyledText {
                visible: Notifs.silenced
                anchors.verticalCenter: parent.verticalCenter
                text: "Silenced"
                color: Theme.red
                font.pixelSize: 11
            }

            // Clear all
            Item {
                visible: Notifs.history.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: clearRow.implicitWidth
                height: clearRow.implicitHeight

                Row {
                    id: clearRow

                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "clear_all"
                        size: 16
                        color: clearArea.containsMouse ? Theme.text1 : Theme.textMuted
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear"
                        color: clearArea.containsMouse ? Theme.text1 : Theme.textMuted
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clear()
                }
            }
        }
    }

    StyledText {
        visible: Notifs.history.length === 0
        width: parent.width
        text: Notifs.silenced ? "Silenced. New notifications collect here quietly." : "No notifications"
        color: Theme.textDim
        font.pixelSize: 13
        wrapMode: Text.Wrap
    }

    // Fills the rest of the page, then scrolls
    Flickable {
        visible: Notifs.history.length > 0
        width: parent.width
        height: Math.min(list.height, root.height - y)
        contentHeight: list.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: Notifs.history
                }

                Item {
                    id: row

                    required property var modelData

                    width: list.width
                    implicitHeight: content.implicitHeight + 16

                    // The body can carry markup, which takes hover for its links, so hover is
                    // tracked on the whole row and the click area sits above the text
                    HoverHandler {
                        id: rowHover
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: rowHover.hovered ? Theme.hover : "transparent"
                    }

                    NotificationContent {
                        id: content

                        x: 8
                        y: 8
                        width: parent.width - 16
                        bodyLines: 2
                        entry: row.modelData
                        showTime: !rowHover.hovered
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.activate(row.modelData)
                    }

                    Rectangle {
                        visible: rowHover.hovered
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 22
                        height: 22
                        radius: 6
                        color: closeArea.containsMouse ? Theme.active : Theme.hover

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            size: 16
                            color: closeArea.containsMouse ? Theme.text1 : Theme.text2
                        }

                        MouseArea {
                            id: closeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.remove(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
