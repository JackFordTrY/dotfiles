pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Claude Code sessions (services/Claude.qml): Claude's logo, then a chip per session with its
// project and what it's doing. A turning ring while it works, a pulsing pink hand while it waits
// on you (a permission or a question), a green check once it's done until you look at its window,
// dim after that. A click goes to the session's window; a right click drops a chip that stayed
// behind. Hidden without sessions.
Row {
    id: root

    readonly property var looks: ({
            working: {
                icon: "progress_activity",
                color: Theme.accent,
                label: "Working"
            },
            waiting: {
                icon: "front_hand",
                color: Theme.pink,
                label: "Waiting for you"
            },
            done: {
                icon: "check_circle",
                color: Theme.green,
                label: "Done"
            },
            idle: {
                icon: "check",
                color: Theme.textDim,
                label: "Idle"
            }
        })

    visible: Claude.sessions.length > 0
    height: parent.height

    Image {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        sourceSize: Qt.size(32, 32)
        source: "file://" + Quickshell.shellPath("assets/claude.svg")
    }

    Repeater {
        model: ScriptModel {
            values: Claude.sessions
            objectProp: "id"
        }

        TabItem {
            id: chip

            required property var modelData
            readonly property var look: root.looks[modelData.state] ?? root.looks.idle

            tooltip: modelData.project + "\n" + (modelData.state === "waiting" && modelData.detail !== "" ? modelData.detail : look.label) + " · " + Notifs.ago(modelData.since)
            onClicked: button => {
                if (button === Qt.LeftButton)
                    Claude.focus(modelData);
                else if (button === Qt.RightButton)
                    Claude.forget(modelData.id);
            }

            MaterialIcon {
                id: indicator

                anchors.verticalCenter: parent.verticalCenter
                text: chip.look.icon
                size: 17
                fill: chip.modelData.state === "done" || chip.lit ? 1 : 0
                color: chip.look.color
                // Upright and solid again once it stops turning or pulsing
                onTextChanged: {
                    rotation = 0;
                    opacity = 1;
                }

                RotationAnimation on rotation {
                    running: chip.modelData.state === "working"
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1400
                }

                SequentialAnimation on opacity {
                    running: chip.modelData.state === "waiting"
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.35
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 120)
                text: chip.modelData.project
                color: chip.hovered ? Theme.text1 : chip.modelData.state === "idle" ? Theme.textMuted : Theme.text2
                elide: Text.ElideRight
            }
        }
    }
}
