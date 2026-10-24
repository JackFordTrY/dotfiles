import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.config

// A 270° ring open at the bottom. The arc is stroked with a left-to-right gradient, so a low
// value stays in `from` and the colour shifts towards `to` as the ring fills. Children are
// centred inside the ring.
Item {
    id: root

    property real value
    property color from: Theme.purple0
    property color to: Theme.blue
    property real size: 84
    property real thickness: 7
    default property alias content: inner.data

    property real shown: Math.max(0, Math.min(1, value))
    readonly property real radius: (size - thickness) / 2 - 2

    implicitWidth: size
    implicitHeight: size

    Behavior on shown {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.surface4
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 135
                sweepAngle: 270
            }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.shown > 0.004
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.to
            shadowOpacity: 0.55
            shadowBlur: 0.6
            blurMax: 16
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            strokeGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.size
                y2: 0

                GradientStop {
                    position: 0.1
                    color: root.from
                }
                GradientStop {
                    position: 0.9
                    color: root.to
                }
            }

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 135
                sweepAngle: 270 * root.shown
            }
        }
    }

    Item {
        id: inner

        anchors.fill: parent
    }
}
