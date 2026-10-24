pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.components

// group/special: clicking the layer-group icon slides out shortcuts to the special workspaces.
Drawer {
    id: root

    clickToReveal: true

    leader: Module {
        id: toggle

        pill: true
        marginRight: 15
        padLeft: 12
        padRight: 12
        background: hovered ? Theme.moduleHover : Theme.moduleBgAlt
        tooltip: "Special workspaces"
        onClicked: button => {
            if (button === Qt.LeftButton)
                root.open = !root.open;
        }

        Label {
            text: ""
            color: toggle.hovered ? Theme.purple2 : Theme.text1
        }
    }

    Repeater {
        model: [
            {
                name: "kitty",
                icon: "",
                tooltip: "Terminal scratchpad"
            },
            {
                name: "ytmusic",
                icon: "",
                tooltip: "YouTube Music"
            },
            {
                name: "trash",
                icon: "",
                tooltip: "Trash"
            }
        ]

        Module {
            id: shortcut

            required property var modelData

            pill: true
            marginRight: 6
            padLeft: 10
            padRight: 10
            animateColors: true
            background: hovered ? Theme.moduleHover : Theme.moduleBg
            tooltip: modelData.tooltip
            onClicked: button => {
                if (button === Qt.LeftButton)
                    Hyprland.dispatch("togglespecialworkspace " + modelData.name);
            }

            Label {
                text: shortcut.modelData.icon
                color: shortcut.hovered ? Theme.purple2 : Theme.text2

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.transitionDuration
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeInOut
                    }
                }
            }
        }
    }
}
