import QtQuick
import QtQuick.Effects
import qs.config

// A 0..1 slider: a gradient fill on a dark track and a round knob. Dragging, clicking and
// scrolling (1% a notch) emit `moved`; `value` is display only, so bind it to the real value.
// With `live` off a drag only previews, and `moved` fires once on release (for seeking).
Item {
    id: root

    property real value
    property color from: Theme.purple0
    property color to: Theme.blue
    // Dims the fill, for a muted device
    property bool dimmed: false
    property bool live: true
    readonly property bool pressed: mouse.pressed
    readonly property real shown: Math.max(0, Math.min(1, pressed ? dragValue : value))
    property real dragValue

    signal moved(real value)

    function clamp(v: real): real {
        return Math.max(0, Math.min(1, v));
    }

    implicitHeight: 20

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface4

        Item {
            width: knob.x + knob.width / 2
            height: parent.height
            clip: true

            Rectangle {
                width: track.width
                height: track.height
                radius: track.radius
                opacity: root.dimmed ? 0.35 : 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: root.from
                    }
                    GradientStop {
                        position: 1
                        color: root.to
                    }
                }
            }
        }
    }

    Rectangle {
        id: knob

        readonly property bool lit: mouse.containsMouse || mouse.pressed

        anchors.verticalCenter: parent.verticalCenter
        x: root.shown * (root.width - width)
        width: 14
        height: 14
        radius: 7
        color: Theme.text1

        layer.enabled: lit
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.mix(root.from, root.to, root.shown)
            shadowOpacity: 0.9
            shadowBlur: 0.6
            blurMax: 10
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    MouseArea {
        id: mouse

        property real wheelDelta: 0

        function drag(x: real) {
            root.dragValue = root.clamp((x - knob.width / 2) / (root.width - knob.width));
            if (root.live)
                root.moved(root.dragValue);
        }

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => drag(event.x)
        onReleased: {
            if (!root.live)
                root.moved(root.dragValue);
        }
        onPositionChanged: event => {
            if (pressed)
                drag(event.x);
        }
        onWheel: wheel => {
            wheelDelta += wheel.angleDelta.y;
            const steps = Math.trunc(wheelDelta / 120);
            if (steps !== 0) {
                wheelDelta -= steps * 120;
                root.moved(root.clamp(Math.round(root.value * 100 + steps) / 100));
            }
        }
    }
}
