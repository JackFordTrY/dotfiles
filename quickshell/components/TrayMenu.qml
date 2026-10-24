pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// A tray item's DBus menu drawn like the GtkMenu Waybar pops up: light Adwaita (Waybar follows
// the system colour scheme, which is "default") with Waybar's `*` rule applied, i.e. the
// JetBrainsMono Nerd Font family, no border and no corner radius.
PopupWindow {
    id: root

    property QsMenuHandle menu
    property Item openEntry

    signal dismissed

    readonly property bool reserveToggle: {
        for (const entry of opener.children.values) {
            if (entry.buttonType !== QsMenuButtonType.None || entry.icon !== "")
                return true;
        }
        return false;
    }

    color: "transparent"
    grabFocus: true
    // `menu { margin: 4px }` keeps the CSD shadow inside the popup surface
    implicitWidth: column.implicitWidth + 8
    implicitHeight: column.implicitHeight + 16

    QsMenuOpener {
        id: opener

        menu: root.menu
    }

    // .csd.popup decoration: box-shadow 0 1px 2px rgba(0,0,0,0.2), 0 0 0 1px rgba(0,0,0,0.13)
    Rectangle {
        x: 3
        y: 4
        width: parent.width - 6
        height: parent.height - 6
        color: Qt.rgba(0, 0, 0, 0.08)
    }

    Rectangle {
        x: 3
        y: 3
        width: parent.width - 6
        height: parent.height - 6
        color: Qt.rgba(0, 0, 0, 0.13)
    }

    Rectangle {
        x: 4
        y: 4
        width: parent.width - 8
        height: parent.height - 8
        color: "#ffffff"

        Column {
            id: column

            y: 4

            Repeater {
                model: opener.children

                delegate: MenuEntry {}
            }
        }
    }

    component MenuEntry: Item {
        id: entry

        required property QsMenuEntry modelData
        readonly property bool hovered: mouse.containsMouse && modelData.enabled
        readonly property color textColor: !modelData.enabled ? "#929595" : hovered ? "#ffffff" : "#2e3436"

        implicitWidth: modelData.isSeparator ? 0 : Math.max(40, 6 + (root.reserveToggle ? 23 : 0) + Math.ceil(label.implicitWidth) + (modelData.hasChildren ? 26 : 0) + 6)
        implicitHeight: modelData.isSeparator ? 1 : 24

        Rectangle {
            width: column.width
            height: parent.height
            color: entry.modelData.isSeparator ? Qt.rgba(0, 0, 0, 0.1) : entry.hovered ? "#3584e4" : "transparent"
        }

        Image {
            visible: entry.modelData.icon !== "" && entry.modelData.buttonType === QsMenuButtonType.None
            x: 6
            y: 4
            width: 16
            height: 16
            sourceSize: Qt.size(16, 16)
            source: entry.modelData.icon
        }

        BarText {
            visible: entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState !== Qt.Unchecked
            x: 6
            size: Theme.defaultFontSize
            baselineY: 19
            color: entry.textColor
            text: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : ""
        }

        BarText {
            id: label

            visible: !entry.modelData.isSeparator
            x: 6 + (root.reserveToggle ? 23 : 0)
            size: Theme.defaultFontSize
            // 16px content box at 4px padding, Pango line 15 + 5
            baselineY: Theme.baseline(4, 16, Theme.defaultFontSize, true, false)
            color: entry.textColor
            text: entry.modelData.text.replace(/_(.)/g, "$1")
        }

        BarText {
            visible: entry.modelData.hasChildren
            x: column.width - 6 - 16
            size: Theme.defaultFontSize
            baselineY: label.baselineY
            color: entry.textColor
            text: ""
        }

        MouseArea {
            id: mouse

            width: column.width
            height: parent.height
            hoverEnabled: true
            enabled: !entry.modelData.isSeparator
            onClicked: {
                if (!entry.modelData.enabled || entry.modelData.hasChildren)
                    return;
                entry.modelData.triggered();
                root.dismissed();
            }
        }

        onHoveredChanged: if (hovered)
            root.openEntry = entry

        // Submenu stays open while the pointer is inside it, until a sibling is hovered
        LazyLoader {
            active: entry.modelData.hasChildren && root.openEntry === entry
            source: Qt.resolvedUrl("TrayMenu.qml")
            onItemChanged: {
                if (!item)
                    return;
                item.menu = entry.modelData;
                item.anchor.item = entry;
                item.anchor.rect.x = column.width;
                item.anchor.edges = Edges.Top | Edges.Right;
                item.anchor.gravity = Edges.Bottom | Edges.Right;
                item.anchor.adjustment = PopupAdjustment.All;
                item.dismissed.connect(root.dismissed);
                item.visible = true;
            }
        }
    }
}
