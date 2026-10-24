import QtQuick
import qs.config

// One control inside a tab: an icon and/or a label. Hovering (or `active`) fills the icon and
// lights it up; the press, wheel and tooltip handling is shared by every bar module.
Item {
    id: root

    property string icon
    property string text
    property real padding: 6
    property bool active: false
    property color iconColor: Theme.text2
    property color textColor: Theme.text2
    property color accentColor: Theme.accent
    property string tooltip
    property bool tooltipMarkup: false
    readonly property alias hovered: hoverHandler.hovered
    readonly property bool lit: active || hovered
    default property alias content: row.data

    // Acts on press, like the old Waybar modules
    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: row.implicitWidth + padding * 2
    height: parent ? parent.height : Theme.tabHeight

    Row {
        id: row

        x: root.padding
        height: parent.height
        spacing: 6

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.lit ? 1 : 0
            glow: root.lit ? 0.9 : 0
            color: root.lit ? root.accentColor : root.iconColor
        }

        StyledText {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.hovered ? Theme.text1 : root.textColor
        }
    }

    HoverHandler {
        id: hoverHandler

        cursorShape: Qt.PointingHandCursor
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
