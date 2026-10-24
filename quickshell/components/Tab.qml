import QtQuick
import qs.config

// A tab standing on the bottom screen edge. Children sit in a row that fills its height; give
// them their own padding so the whole tab is clickable.
Item {
    id: root

    property real padding: 6
    property alias spacing: row.spacing
    property alias color: shape.color
    default property alias content: row.data

    y: parent ? parent.height - height : 0
    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.tabHeight

    EdgeShape {
        id: shape

        x: -Theme.flare
        bodyWidth: root.width
        bodyHeight: root.height
    }

    Row {
        id: row

        x: root.padding
        height: parent.height
    }
}
