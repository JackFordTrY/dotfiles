import QtQuick
import qs.config

// Waybar group drawer: the leader is always shown and the rest sit in a GtkRevealer that opens
// on hover (or on left click with click-to-reveal). The revealer's width eases out (cubic) over
// 300ms with its content pinned to its left edge, as GTK's SLIDE_LEFT transition does.
Item {
    id: root

    property bool clickToReveal: false
    // transition-left-to-right: the drawer sits right of the leader (false: left of it)
    property bool leftToRight: true
    // CSS margin on the group box itself (Waybar names it after the group, e.g. #tray)
    property real marginRight: 0
    property bool open: false
    property alias leader: leaderSlot.data
    default property alias items: drawerRow.data

    property real progress: open ? 1 : 0
    readonly property int revealWidth: Math.round(drawerRow.implicitWidth * progress)

    implicitWidth: leaderSlot.implicitWidth + revealWidth + marginRight
    implicitHeight: Theme.barHeight

    Behavior on progress {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: leaderSlot

        x: root.leftToRight ? 0 : root.revealWidth
        implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
        height: parent.height
    }

    Item {
        x: root.leftToRight ? leaderSlot.implicitWidth : 0
        width: root.revealWidth
        height: parent.height
        clip: true

        Row {
            id: drawerRow

            height: parent.height
        }
    }

    HoverHandler {
        enabled: !root.clickToReveal
        onHoveredChanged: root.open = hovered
    }
}
