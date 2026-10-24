import QtQuick
import Quickshell
import qs.config
import qs.components

// The time over the date in small spaced caps ("14:32" / "SAT 24 OCT"); hovering it shows the
// month in the right tab's panel (see Controls).
TabItem {
    id: root

    padding: 8

    Column {
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: root.hovered ? "white" : Theme.text1
            font.pixelSize: 14
            font.bold: true
        }

        StyledText {
            text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
            color: root.hovered ? Theme.text2 : Theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.3
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
