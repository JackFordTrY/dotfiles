import QtQuick
import qs.config

// Four bars that bounce out of step while `playing` and settle low when it stops
Row {
    id: root

    property bool playing
    property color from: Theme.purple0
    property color to: Theme.blue

    height: 14
    spacing: 2

    Repeater {
        // How high each bar peaks and how long one bounce takes
        model: [
            {
                peak: 0.6,
                duration: 420
            },
            {
                peak: 1,
                duration: 540
            },
            {
                peak: 0.75,
                duration: 380
            },
            {
                peak: 0.5,
                duration: 480
            }
        ]

        Rectangle {
            id: bar

            required property var modelData
            required property int index
            property real level: 0.3

            anchors.bottom: parent.bottom
            width: 3
            height: Math.max(2, root.height * level)
            radius: 1.5
            color: Theme.mix(root.from, root.to, index / 3)

            SequentialAnimation {
                running: root.playing
                loops: Animation.Infinite

                NumberAnimation {
                    target: bar
                    property: "level"
                    to: bar.modelData.peak
                    duration: bar.modelData.duration / 2
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: bar
                    property: "level"
                    to: 0.2
                    duration: bar.modelData.duration / 2
                    easing.type: Easing.InOutSine
                }
            }

            NumberAnimation {
                running: !root.playing
                target: bar
                property: "level"
                to: 0.3
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
}
