import QtQuick

// One page of a panel. Pages share a slot and cross-fade as `shown` moves between them; hidden
// pages stay loaded
Item {
    property bool shown

    anchors.fill: parent
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
}
