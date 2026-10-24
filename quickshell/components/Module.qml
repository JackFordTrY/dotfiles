import QtQuick
import qs.config

// One Waybar module laid out like GTK does it: CSS margin, an optional pill (background clipped
// to the border box with the 1px border drawn over it), padding, then the label content.
// The whole allocation (margins included) is the event box, so it takes hover and clicks.
Item {
    id: root

    property real marginLeft: 0
    property real marginRight: 0
    property real padLeft: 0
    property real padRight: 0
    property bool pill: false
    property real radius: 15
    property color background: "transparent"
    property color borderColor: Theme.moduleBorder
    property bool animateColors: false
    property string tooltip
    property bool tooltipMarkup: false
    readonly property alias hovered: hoverHandler.hovered
    default property alias content: contentRow.data

    // Waybar acts on button press, not release
    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: marginLeft + (pill ? 2 : 0) + padLeft + Math.ceil(contentRow.implicitWidth) + padRight + marginRight
    implicitHeight: Theme.barHeight

    Rectangle {
        visible: root.pill
        x: root.marginLeft
        y: Theme.pillTop
        width: root.width - root.marginLeft - root.marginRight
        height: Theme.pillHeight
        radius: root.radius
        color: root.background

        Behavior on color {
            enabled: root.animateColors

            ColorAnimation {
                duration: Theme.transitionDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeInOut
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.borderColor
        }
    }

    Row {
        id: contentRow

        x: root.marginLeft + (root.pill ? 1 : 0) + root.padLeft
        height: parent.height
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        property real wheelDelta: 0

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: mouse => {
            tooltip.dismiss();
            root.clicked(mouse.button);
        }
        onWheel: wheel => {
            wheelDelta += wheel.angleDelta.y;
            const steps = Math.trunc(wheelDelta / 120);
            if (steps !== 0) {
                wheelDelta -= steps * 120;
                root.scrolled(steps);
            }
        }
    }

    Tooltip {
        id: tooltip

        target: root
        text: root.tooltip
        markup: root.tooltipMarkup
        hovered: root.hovered
        pointerX: hoverHandler.point.position.x
    }
}
