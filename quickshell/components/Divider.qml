import QtQuick
import qs.config

// A short vertical rule separating groups that share a tab
Item {
    implicitWidth: 13
    height: parent ? parent.height : Theme.tabHeight

    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: 16
        color: Theme.purpleGlowStrong
    }
}
