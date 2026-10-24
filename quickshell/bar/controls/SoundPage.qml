pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Output and mic volume, a picker when there is more than one output, and a volume per app that
// is playing audio. Clicking an icon mutes that row.
Column {
    id: root

    spacing: 6

    SectionLabel {
        text: "OUTPUT"
    }

    VolumeRow {
        node: Audio.sink
        icon: muted ? "volume_off" : (node?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up"
        label: Audio.sinkName(Audio.sink)
    }

    VolumeRow {
        node: Audio.source
        icon: muted ? "mic_off" : "mic"
        label: "Mic"
        from: Theme.pink
        to: Theme.purple2
    }

    Flow {
        visible: Audio.sinks.length > 1
        width: parent.width
        spacing: 6
        topPadding: 2

        Repeater {
            model: ScriptModel {
                values: Audio.sinks
            }

            Chip {
                required property PwNode modelData

                icon: /bluez/.test(modelData.name) ? "headphones" : "speaker"
                text: Audio.sinkName(modelData)
                active: modelData === Audio.sink
                onClicked: Audio.setSink(modelData)
            }
        }
    }

    SectionLabel {
        topPadding: 10
        text: "APPS"
    }

    StyledText {
        visible: Audio.streams.length === 0
        text: "Nothing is playing"
        color: Theme.textDim
        font.pixelSize: 13
    }

    // Fills the rest of the page, then scrolls
    Flickable {
        visible: Audio.streams.length > 0
        width: parent.width
        height: Math.min(apps.height, root.height - y)
        contentHeight: apps.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: apps

            width: parent.width
            spacing: 6

            Repeater {
                model: ScriptModel {
                    values: Audio.streams
                }

                VolumeRow {
                    required property PwNode modelData

                    node: modelData
                    image: Audio.appIcon(modelData)
                    icon: "graphic_eq"
                    label: Audio.appName(modelData)
                    from: Theme.blue
                    to: Theme.cyan
                }
            }
        }
    }

    component VolumeRow: Item {
        id: row

        property PwNode node
        property string icon
        // An app icon, shown instead of `icon` when set
        property string image
        property string label
        property color from: Theme.purple0
        property color to: Theme.blue
        readonly property real volume: node?.audio?.volume ?? 0
        readonly property bool muted: node?.audio?.muted ?? false

        width: root.width
        implicitHeight: 34

        Rectangle {
            id: muteButton

            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 8
            color: muteArea.containsMouse ? Theme.hover : "transparent"

            MaterialIcon {
                visible: row.image === "" || row.muted
                anchors.centerIn: parent
                text: row.muted && row.image !== "" ? "volume_off" : row.icon
                fill: muteArea.containsMouse ? 1 : 0
                color: row.muted ? Theme.red : Theme.text2
            }

            IconImage {
                visible: row.image !== "" && !row.muted
                anchors.centerIn: parent
                implicitSize: 20
                source: row.image
            }

            MouseArea {
                id: muteArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: Audio.toggleMute(row.node)
            }
        }

        StyledText {
            id: name

            anchors.left: muteButton.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            text: row.label
            color: row.muted ? Theme.textDim : Theme.text2
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        StyledSlider {
            anchors.left: name.right
            anchors.leftMargin: 8
            anchors.right: percent.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            value: row.volume
            from: row.from
            to: row.to
            dimmed: row.muted
            onMoved: value => Audio.setVolume(row.node, value)
        }

        StyledText {
            id: percent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(row.volume * 100) + "%"
            color: row.muted ? Theme.textDim : Theme.text2
            font.pixelSize: 12
        }
    }
}
