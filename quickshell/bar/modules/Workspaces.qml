pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

// hyprland/workspaces: persistent 1-5 plus any other regular workspace from all outputs, in
// Waybar's default order. Buttons are GTK flat buttons (Adwaita min-width 16px, .active 40px)
// whose width and background follow `transition: all 0.3s ease-in-out`.
Item {
    id: root

    readonly property var workspaces: {
        const list = Hyprland.workspaces.values.filter(w => !w.name.startsWith("special")).map(w => ({
                    id: w.id,
                    name: w.name
                }));
        for (let id = 1; id <= 5; id++) {
            if (!list.some(w => w.id === id))
                list.push({
                    id: id,
                    name: String(id)
                });
        }
        // numbered by id, then named by name
        return list.sort((a, b) => {
            if (a.id > 0 && b.id > 0)
                return a.id - b.id;
            if ((a.id > 0) !== (b.id > 0))
                return a.id > 0 ? -1 : 1;
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        });
    }

    // #workspaces: margin 0 1px, transparent 1px border, padding 0 1px
    implicitWidth: row.implicitWidth + 6
    implicitHeight: Theme.barHeight

    Row {
        id: row

        x: 3
        height: parent.height

        Repeater {
            model: ScriptModel {
                values: root.workspaces
                objectProp: "id"
            }

            WorkspaceButton {}
        }
    }

    component WorkspaceButton: Item {
        id: button

        required property var modelData
        readonly property bool active: Hyprland.focusedWorkspace?.id === modelData.id
        property real minWidth: active ? 40 : 16
        readonly property int buttonWidth: Math.round(Math.max(minWidth, Math.ceil(label.implicitWidth))) + 10

        // button: margin 4px 3px, padding 0 5px, 25px tall inside the box's 5px/6px margins
        implicitWidth: buttonWidth + 6
        implicitHeight: Theme.barHeight

        Behavior on minWidth {
            NumberAnimation {
                duration: Theme.transitionDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeInOut
            }
        }

        Rectangle {
            x: 3
            y: 10
            width: button.buttonWidth
            height: 25
            radius: 15
            color: mouse.containsMouse ? Theme.moduleHover : button.active ? Theme.surface5 : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.transitionDuration
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeInOut
                }
            }

            // box-shadow: inset 0 0 0 1px @purpleGlowStrong
            Rectangle {
                visible: button.active
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.purpleGlowStrong
            }
        }

        BarText {
            id: label

            x: 8 + Math.floor((button.buttonWidth - 10 - Math.ceil(implicitWidth)) / 2)
            bold: true
            baselineY: Theme.baseline(10, 25, 16, true, false)
            // format "{}" is the first argument, the workspace id
            text: String(button.modelData.id)
        }

        MouseArea {
            id: mouse

            x: 3
            y: 10
            width: button.buttonWidth
            height: 25
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onPressed: Hyprland.dispatch(button.modelData.id > 0 ? "workspace " + button.modelData.id : "workspace name:" + button.modelData.name)
        }
    }
}
