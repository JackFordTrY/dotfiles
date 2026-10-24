pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.components

// The system tray as a strip of icons in the controls panel; passive items stay hidden. While
// one of the menus is open, `menuOpen` keeps the panel from closing under it.
Row {
    id: root

    property int openMenus: 0
    readonly property bool menuOpen: openMenus > 0
    readonly property int count: items.count

    spacing: 2

    Repeater {
        id: items

        model: ScriptModel {
            values: SystemTray.items.values.filter(item => item.status !== Status.Passive)
        }

        TrayItem {}
    }

    component TrayItem: Item {
        id: trayItem

        required property SystemTrayItem modelData
        property point menuPos
        property bool menuOpen: false

        implicitWidth: 32
        implicitHeight: 32
        onMenuOpenChanged: root.openMenus += menuOpen ? 1 : -1

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: itemHover.hovered || trayItem.menuOpen ? Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration
                    easing.type: Easing.OutCubic
                }
            }
        }

        ThemedIcon {
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize: Qt.size(18, 18)
            icon: trayItem.modelData.icon
        }

        Rectangle {
            visible: trayItem.modelData.status === Status.NeedsAttention
            x: parent.width / 2 + 5
            y: parent.height / 2 - 10
            width: 6
            height: 6
            radius: 3
            color: Theme.red
        }

        HoverHandler {
            id: itemHover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            property real wheelDelta: 0

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onPressed: mouse => {
                tooltip.dismiss();
                const item = trayItem.modelData;
                if ((mouse.button === Qt.LeftButton && item.onlyMenu) || mouse.button === Qt.RightButton) {
                    if (item.hasMenu) {
                        trayItem.menuPos = Qt.point(mouse.x, mouse.y);
                        trayItem.menuOpen = true;
                    } else {
                        const pos = trayItem.QsWindow.window.mapFromItem(trayItem, mouse.x, mouse.y);
                        item.display(trayItem.QsWindow.window, pos.x, pos.y);
                    }
                } else if (mouse.button === Qt.LeftButton) {
                    item.activate();
                } else if (mouse.button === Qt.MiddleButton) {
                    item.secondaryActivate();
                }
            }
            onWheel: wheel => {
                wheelDelta += wheel.angleDelta.y;
                const steps = Math.trunc(wheelDelta / 120);
                if (steps !== 0) {
                    wheelDelta -= steps * 120;
                    trayItem.modelData.scroll(-steps, false);
                }
            }
        }

        Tooltip {
            id: tooltip

            target: trayItem
            markup: true
            hovered: itemHover.hovered && !trayItem.menuOpen
            pointerX: itemHover.point.position.x
            text: {
                const item = trayItem.modelData;
                if (item.tooltipTitle === "")
                    return item.title;
                return item.tooltipDescription === "" ? item.tooltipTitle : item.tooltipTitle + "\n" + item.tooltipDescription;
            }
        }

        // Opens above the pointer, flipping or sliding to stay on screen
        LazyLoader {
            active: trayItem.menuOpen

            TrayMenu {
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.rect.x: trayItem.menuPos.x
                anchor.rect.y: trayItem.menuPos.y
                anchor.rect.width: 1
                anchor.rect.height: 1
                anchor.edges: Edges.Top | Edges.Right
                anchor.gravity: Edges.Top | Edges.Right
                anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
                visible: true
                onDismissed: trayItem.menuOpen = false
                onVisibleChanged: if (!visible)
                    trayItem.menuOpen = false
            }
        }
    }
}
