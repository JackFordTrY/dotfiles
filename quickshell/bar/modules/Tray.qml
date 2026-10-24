pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

// group/tray: hovering the chevron slides the tray out on its left. Passive items stay hidden
// (Waybar's show-passive-items default); icons are 16px with 10px spacing.
Drawer {
    leftToRight: false
    // #tray { margin-right: 10px } also matches the group box, which Waybar names "tray"
    marginRight: 10

    leader: Module {
        marginRight: 12

        Label {
            text: ""
            size: 20
            bold: true
            baselineY: Theme.baseline(0, Theme.barHeight, 20, true, false)
        }
    }

    Item {
        implicitWidth: items.implicitWidth + 10
        height: parent.height

        Row {
            id: items

            height: parent.height
            spacing: 10

            Repeater {
                model: ScriptModel {
                    values: SystemTray.items.values.filter(item => item.status !== Status.Passive)
                }

                TrayItem {}
            }
        }
    }

    component TrayItem: Item {
        id: trayItem

        required property SystemTrayItem modelData
        property point menuPos
        property bool menuOpen: false

        implicitWidth: 16
        height: parent.height

        // #tray > .needs-attention
        Rectangle {
            anchors.fill: parent
            visible: trayItem.modelData.status === Status.NeedsAttention
            color: Theme.red
        }

        IconImage {
            y: Math.floor((parent.height - 16) / 2)
            implicitSize: 16
            source: trayItem.modelData.icon
        }

        HoverHandler {
            id: hover
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
            hovered: hover.hovered && !trayItem.menuOpen
            pointerX: hover.point.position.x
            text: {
                const item = trayItem.modelData;
                if (item.tooltipTitle === "")
                    return item.title;
                return item.tooltipDescription === "" ? item.tooltipTitle : item.tooltipTitle + "\n" + item.tooltipDescription;
            }
        }

        // gtk_menu_popup_at_pointer, flipped above the pointer on the bottom bar
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
