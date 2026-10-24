pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components

// The power options as a row of icons. Suspend acts on the first click; logging out, rebooting
// and shutting down turn into a check mark that has to be clicked again before the bar under it
// runs out. Hibernate and lock are left out: logind can't hibernate here (swap is zram only) and
// no screen locker is installed.
Row {
    id: root

    // The panel is open on this page; closing it calls off a pending confirmation
    property bool active
    // The option waiting for its confirming click
    property string armed: ""

    // An option has been carried out
    signal ran

    function press(option: var) {
        if (option.confirm && armed !== option.name) {
            armed = option.name;
            disarm.restart();
            return;
        }
        armed = "";
        disarm.stop();
        ran();
        Quickshell.execDetached(option.command);
    }

    spacing: 10
    onActiveChanged: {
        if (!active)
            armed = "";
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    Repeater {
        model: [
            {
                name: "suspend",
                icon: "bedtime",
                color: Theme.blue,
                confirm: false,
                command: ["systemctl", "suspend"]
            },
            {
                name: "logout",
                icon: "logout",
                color: Theme.purple2,
                confirm: true,
                // As SUPER + M does: apps get to close first
                command: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"]
            },
            {
                name: "reboot",
                icon: "restart_alt",
                color: Theme.pink,
                confirm: true,
                command: ["systemctl", "reboot"]
            },
            {
                name: "shutdown",
                icon: "power_settings_new",
                color: Theme.red,
                confirm: true,
                command: ["systemctl", "poweroff"]
            }
        ]

        Option {}
    }

    component Option: Rectangle {
        id: option

        required property var modelData
        readonly property bool armed: root.armed === modelData.name
        readonly property bool lit: armed || area.containsMouse

        width: (root.width - root.spacing * 3) / 4
        height: 64
        radius: 12
        color: armed ? Qt.alpha(modelData.color, 0.2) : area.containsMouse ? Theme.hover : Theme.raised
        border.width: 1
        border.color: armed ? Qt.alpha(modelData.color, 0.6) : area.containsMouse ? Theme.purpleGlowStrong : Theme.purpleGlow

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration
                easing.type: Easing.OutCubic
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: option.armed ? "check" : option.modelData.icon
            size: 28
            fill: option.lit ? 1 : 0
            glow: option.lit ? 0.9 : 0
            glowColor: option.modelData.color
            color: option.lit ? option.modelData.color : Theme.text2
        }

        // The time left to confirm
        Rectangle {
            property real remaining: 1

            visible: option.armed
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            width: (parent.width - 28) * remaining
            height: 3
            radius: 1.5
            color: option.modelData.color

            NumberAnimation on remaining {
                running: option.armed
                from: 1
                to: 0
                duration: disarm.interval
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.press(option.modelData)
        }
    }
}
