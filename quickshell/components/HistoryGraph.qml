import QtQuick
import QtQuick.Shapes
import qs.config

// A line graph of the last `capacity` samples (0-1, oldest first) that scrolls in from the
// right, stroked with a `from`→`to` gradient over a fading area fill.
Item {
    id: root

    property var values: []
    property int capacity: 60
    property color from: Theme.purple0
    property color to: Theme.blue
    property real lineWidth: 1.5
    property real areaOpacity: 0.3

    readonly property var points: {
        const step = width / Math.max(1, capacity - 1);
        const offset = capacity - values.length;
        const top = lineWidth;
        const span = height - lineWidth * 2;
        return values.map((v, i) => Qt.point((offset + i) * step, top + (1 - Math.max(0, Math.min(1, v))) * span));
    }

    Shape {
        anchors.fill: parent
        visible: root.points.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height

                GradientStop {
                    position: 0
                    color: Qt.alpha(root.from, root.areaOpacity)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(root.to, 0)
                }
            }

            PathPolyline {
                path: root.points.length > 1 ? root.points.concat([Qt.point(root.points[root.points.length - 1].x, root.height), Qt.point(root.points[0].x, root.height)]) : []
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.lineWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            strokeGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.width
                y2: 0

                GradientStop {
                    position: 0
                    color: root.from
                }
                GradientStop {
                    position: 1
                    color: root.to
                }
            }

            PathPolyline {
                path: root.points
            }
        }
    }
}
