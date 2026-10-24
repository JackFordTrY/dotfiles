import QtQuick
import qs.config

// A tab that grows out of the bar into a panel. The tab's row stays put on the screen edge
// while the panel opens around it, and `body` (laid out at full size, top-left of the open
// panel's content) fades in. `trigger` opens it after a short dwell; once open, the whole panel
// keeps it open.
Item {
    id: root

    property real expandedWidth
    property real expandedHeight
    // The point of the tab that stays put as the panel grows: 0 its left edge, 1 its right edge
    // (tabs on the right of the bar), 0.5 its middle
    property real growOrigin: 0
    property int hoverDelay: Theme.hoverDelay
    property int closeDelay: 250
    property int openDuration: Theme.openDuration
    property int closeDuration: Theme.closeDuration
    property bool trigger: false
    // Stays open whatever the pointer does, e.g. while typing a password
    property bool pinned: false
    property bool open: false
    property real progress: open ? 1 : 0
    // The closed tab's width; override it when the row holds things that only show once open
    property real collapsedWidth: row.implicitWidth + 12
    readonly property real openWidth: Math.max(expandedWidth, collapsedWidth)
    readonly property bool hovered: trigger || (open && panelHover.hovered)
    readonly property alias panel: panel
    // The pointer over the panel, in its coordinates. Tracked by the panel itself; handlers on
    // items in the row can miss moves while the panel is open
    readonly property alias panelHovered: panelHover.hovered
    readonly property alias pointer: panelHover.point
    property alias body: body.data
    default property alias content: row.data

    // Opens right away, e.g. on a click
    function show() {
        openTimer.stop();
        closeTimer.stop();
        open = true;
    }

    implicitWidth: collapsedWidth
    height: parent.height
    onHoveredChanged: {
        if (hovered) {
            closeTimer.stop();
            if (!open)
                openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }
    onPinnedChanged: {
        if (!pinned && !hovered)
            closeTimer.restart();
    }

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? root.openDuration : root.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }

    Timer {
        id: openTimer

        interval: root.hoverDelay
        onTriggered: root.open = true
    }

    Timer {
        id: closeTimer

        interval: root.closeDelay
        onTriggered: {
            if (!root.pinned)
                root.open = false;
        }
    }

    Item {
        id: panel

        readonly property real p: root.progress

        width: root.collapsedWidth + (root.openWidth - root.collapsedWidth) * p
        height: Theme.tabHeight + (root.expandedHeight - Theme.tabHeight) * p
        x: (root.width - width) * root.growOrigin
        y: root.height - height

        EdgeShape {
            x: -Theme.flare
            bodyWidth: panel.width
            bodyHeight: panel.height
            radius: Theme.tabRadius + 6 * panel.p
        }

        HoverHandler {
            id: panelHover
        }

        Item {
            anchors.fill: parent
            clip: true

            // Clipped to its side of the row, so a page that grows faster than the panel can't
            // cover it
            Item {
                id: body

                x: (parent.width - width) * root.growOrigin
                y: parent.height - root.expandedHeight
                width: root.openWidth
                height: root.expandedHeight - Theme.tabHeight
                opacity: Math.max(0, panel.p * 2 - 1)
                visible: opacity > 0
                clip: true
            }

            Row {
                id: row

                x: (parent.width - root.width) * root.growOrigin + 6
                y: parent.height - Theme.tabHeight
                height: Theme.tabHeight
            }
        }
    }
}
