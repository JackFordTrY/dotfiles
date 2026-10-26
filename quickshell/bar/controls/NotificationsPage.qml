pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The last five minutes' notifications, grouped by app (the app with the newest first) and newest
// first within; they stay that long unless cleared here, one at a time, an app's at once or all. A group shows its
// newest two until it's opened up. Clicking one follows it (the app's own action while the
// notification is alive, else the app's window); the cross removes it. Opening the page marks
// everything read.
Column {
    id: root

    // Showing on screen
    property bool active
    // Shown before a group needs opening up
    readonly property int folded: 2
    // Apps showing every notification, by name
    property var expanded: ({})
    readonly property var groups: {
        const byApp = new Map();
        for (const entry of Notifs.history) {
            const app = Notifs.appOf(entry);
            if (!byApp.has(app))
                byApp.set(app, []);
            byApp.get(app).push(entry);
        }
        return [...byApp].map(([app, entries]) => ({
                    app: app,
                    entries: entries
                }));
    }

    function toggle(app: string) {
        const expanded = Object.assign({}, root.expanded);
        expanded[app] = !expanded[app];
        root.expanded = expanded;
    }

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
                visible: Notifs.paused
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.silenced ? "Silenced" : "Paused while sharing"
                color: Notifs.silenced ? Theme.red : Theme.pink
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
                        text: "Clear all"
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
        text: Notifs.silenced ? "Silenced. New notifications collect here quietly for 5 minutes." : "No notifications"
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
            spacing: 10

            Repeater {
                model: ScriptModel {
                    values: root.groups
                    objectProp: "app"
                }

                Group {}
            }
        }
    }

    component Group: Column {
        id: group

        required property var modelData
        readonly property bool open: root.expanded[modelData.app] ?? false
        readonly property int hidden: open ? 0 : Math.max(0, modelData.entries.length - root.folded)

        width: list.width
        spacing: 2

        Item {
            width: parent.width
            height: 22

            StyledText {
                id: appName

                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - actions.width - 60)
                text: group.modelData.app
                color: Theme.text2
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }

            StyledText {
                anchors.left: appName.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: group.modelData.entries.length
                color: Theme.textDim
                font.pixelSize: 11
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                TextButton {
                    visible: group.modelData.entries.length > root.folded
                    icon: group.open ? "unfold_less" : "unfold_more"
                    text: group.open ? "Show less" : "Show all"
                    onClicked: root.toggle(group.modelData.app)
                }

                TextButton {
                    icon: "clear_all"
                    text: "Clear"
                    onClicked: Notifs.clearApp(group.modelData.app)
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: group.open ? group.modelData.entries : group.modelData.entries.slice(0, root.folded)
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

        StyledText {
            visible: group.hidden > 0
            x: 8
            text: group.hidden + " more"
            color: Theme.textDim
            font.pixelSize: 11
        }
    }

    // A small icon and label, like the header's Clear
    component TextButton: Item {
        id: button

        property string icon
        property string text

        signal clicked

        width: buttonRow.implicitWidth
        height: buttonRow.implicitHeight

        Row {
            id: buttonRow

            spacing: 4

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: button.icon
                size: 16
                color: buttonArea.containsMouse ? Theme.text1 : Theme.textMuted
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                color: buttonArea.containsMouse ? Theme.text1 : Theme.textMuted
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
