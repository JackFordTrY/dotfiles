pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// A tray item's DBus menu. Submenus open beside their entry and stay open while the pointer is
// inside them, until a sibling entry is hovered.
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
    implicitWidth: column.implicitWidth + 12
    implicitHeight: column.implicitHeight + 12

    QsMenuOpener {
        id: opener

        menu: root.menu
    }

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
        readonly property color textColor: !modelData.enabled ? Theme.textDim : hovered ? Theme.text1 : Theme.text2
        readonly property string toggleIcon: {
            if (modelData.buttonType === QsMenuButtonType.RadioButton)
                return modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked";
            if (modelData.buttonType === QsMenuButtonType.CheckBox)
                return modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank";
            return "";
        }

        implicitWidth: modelData.isSeparator ? 0 : Math.max(120, 10 + (root.reserveToggle ? 26 : 0) + Math.ceil(label.implicitWidth) + (modelData.hasChildren ? 26 : 0) + 12)
        implicitHeight: modelData.isSeparator ? 9 : 30

        Rectangle {
            visible: entry.modelData.isSeparator
            x: 6
            y: 4
            width: column.width - 12
            height: 1
            color: Theme.border
        }

        Rectangle {
            visible: !entry.modelData.isSeparator
            width: column.width
            height: parent.height
            radius: 8
            color: entry.hovered ? Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        ThemedIcon {
            visible: resolved !== "" && entry.toggleIcon === ""
            x: 10
            y: 7
            width: 16
            height: 16
            sourceSize: Qt.size(16, 16)
            icon: entry.modelData.icon
            color: entry.textColor
        }

        MaterialIcon {
            visible: entry.toggleIcon !== ""
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            size: 18
            text: entry.toggleIcon
            fill: entry.modelData.checkState === Qt.Checked ? 1 : 0
            color: entry.modelData.checkState === Qt.Checked ? Theme.accent : entry.textColor
        }

        StyledText {
            id: label

            visible: !entry.modelData.isSeparator
            x: 10 + (root.reserveToggle ? 26 : 0)
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
            color: entry.textColor
            text: entry.modelData.text.replace(/_(.)/g, "$1")
        }

        MaterialIcon {
            visible: entry.modelData.hasChildren
            x: column.width - 8 - width
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            color: entry.textColor
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

        LazyLoader {
            active: entry.modelData.hasChildren && root.openEntry === entry
            source: Qt.resolvedUrl("TrayMenu.qml")
            onItemChanged: {
                if (!item)
                    return;
                item.menu = entry.modelData;
                item.anchor.item = entry;
                item.anchor.rect.x = column.width + 6;
                item.anchor.rect.y = -6;
                item.anchor.edges = Edges.Top | Edges.Right;
                item.anchor.gravity = Edges.Bottom | Edges.Right;
                item.anchor.adjustment = PopupAdjustment.All;
                item.dismissed.connect(root.dismissed);
                item.visible = true;
            }
        }
    }
}
