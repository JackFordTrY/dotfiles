pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Notification banners in one shape hanging from the top edge in the top-right corner of the
// focused monitor. A new one drips out of the edge: a narrow drop pushes down with a springy
// overshoot, then widens into the card, and the text fades in once it's nearly there. More
// notifications grow the drop the same way; when the last goes it narrows and pulls back up into
// the edge. At most three at a time, the newest pushing out the oldest, each at most twice the
// height of a one-line notification. A burst from one conversation shares a banner, showing the
// newest with a count. A line under each runs out with the time it has left.
// Hovering holds the banners; a click follows the
// notification, a right click or the cross hides the banner at once. Everything stays in the
// history.
PanelWindow {
    id: root

    readonly property real cardWidth: 380
    readonly property bool any: Notifs.popups.length > 0

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: any || drop.height > 0.5
    anchors {
        left: true
        right: true
        top: true
    }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    // Room for three banners (plus any action buttons) and the glow under them
    implicitHeight: 560
    color: "transparent"

    mask: Region {
        x: drop.x
        width: drop.width
        height: drop.height
    }

    Item {
        id: drop

        // A narrow drop while empty, so the shape grows out of the edge rather than popping in
        readonly property real targetWidth: root.any ? root.cardWidth + 32 : 56
        readonly property real targetHeight: root.any ? cards.implicitHeight + 28 : 0
        readonly property real fullness: targetHeight > 0 ? Math.min(1, height / targetHeight) : 0

        // Inset from the right edge like the bar's right tab, widening leftwards
        x: root.width - width - Theme.edgePadding - Theme.flare
        width: targetWidth
        height: targetHeight

        Behavior on height {
            NumberAnimation {
                duration: root.any ? 460 : 220
                easing.type: root.any ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.4
            }
        }

        // Widens just after the drop starts falling, narrows just before it's gone
        Behavior on width {
            SequentialAnimation {
                PauseAnimation {
                    duration: 70
                }
                NumberAnimation {
                    duration: root.any ? 300 : 160
                    easing.type: root.any ? Easing.OutCubic : Easing.InCubic
                }
            }
        }

        EdgeShape {
            id: shape

            x: -Theme.flare
            bodyWidth: drop.width
            bodyHeight: drop.height
            radius: Theme.tabRadius + 6
            color: Theme.notificationBackground
            glowBehind: true

            // Hangs from the top edge
            transform: Scale {
                origin.y: shape.height / 2
                yScale: -1
            }
        }

        HoverHandler {
            id: hover
        }

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: cards

                x: 16
                y: 14
                width: root.cardWidth
                spacing: 10
                opacity: Math.max(0, (drop.fullness - 0.7) / 0.3)

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 220
                    }
                }
                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: Notifs.popups
                    }

                    Card {}
                }
            }
        }
    }

    component Card: Item {
        id: card

        required property var modelData
        required property int index
        readonly property var actions: (modelData.notification?.actions ?? []).filter(a => a.identifier !== "default")

        width: root.cardWidth
        implicitHeight: content.implicitHeight + (actionRow.visible ? actionRow.height + 10 : 0) + (index > 0 ? 11 : 0) + (countdown.visible ? 8 : 0)

        // Between banners
        Rectangle {
            visible: card.index > 0
            width: parent.width
            height: 1
            color: Theme.purpleGlow
        }

        // The body can carry markup, which takes hover for its links, so hover is tracked on the
        // whole banner and the click area sits above the text
        HoverHandler {
            id: cardHover
        }

        NotificationContent {
            id: content

            y: card.index > 0 ? 11 : 0
            width: parent.width
            entry: card.modelData
            count: card.modelData.burst ?? 1
            showTime: !cardHover.hovered
            // No banner taller than twice a one-line notification; the body is trimmed to fit
            maxHeight: oneLineHeight * 2
            bodyLines: 20
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Notifs.hidePopup(card.modelData);
                else
                    Notifs.activate(card.modelData);
            }
        }

        Flow {
            id: actionRow

            visible: card.actions.length > 0
            anchors.top: content.bottom
            anchors.topMargin: 10
            x: 48
            width: parent.width - 48
            spacing: 6

            Repeater {
                model: card.actions

                Chip {
                    required property var modelData

                    text: modelData.text
                    onClicked: Notifs.invoke(card.modelData, modelData)
                }
            }
        }

        // Shown while hovered, over the time
        Rectangle {
            visible: cardHover.hovered
            anchors.top: content.top
            anchors.right: parent.right
            anchors.topMargin: -4
            width: 22
            height: 22
            radius: 6
            color: closeArea.containsMouse ? Theme.hover : Theme.notificationBackground

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
                onClicked: Notifs.hidePopup(card.modelData)
            }
        }

        Timer {
            id: timeout

            interval: Notifs.popupTimeout(card.modelData)
            running: interval > 0 && !hover.hovered
            onTriggered: Notifs.hidePopup(card.modelData)
        }

        // The time left, as a line under the text that runs out with it. Hovering fills it back
        // up, as the time starts over once the pointer leaves
        Rectangle {
            id: countdown

            property real remaining: 1

            visible: timeout.interval > 0
            x: 48
            y: card.height - height
            width: (card.width - x) * remaining
            height: 2
            radius: 1
            color: Theme.accent
            opacity: 0.7

            NumberAnimation {
                target: countdown
                property: "remaining"
                running: timeout.running
                from: 1
                to: 0
                duration: timeout.interval
            }

            NumberAnimation {
                target: countdown
                property: "remaining"
                running: hover.hovered
                to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
