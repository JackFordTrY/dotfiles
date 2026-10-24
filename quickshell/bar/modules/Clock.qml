import QtQuick
import Quickshell
import qs.config
import qs.components

// The time over the date in small spaced caps ("14:32" / "SAT 24 OCT"), the full date in the
// tooltip; left click opens the ml4w calendar.
TabItem {
    id: root

    padding: 8
    tooltip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["sh", "-c", "flatpak run com.ml4w.calendar"]);
    }

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
