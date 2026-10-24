import QtQuick
import Quickshell
import qs.config
import qs.components

// clock: "{:%H:%M %a}", left click runs the ml4w calendar like the Waybar module.
Module {
    pill: true
    marginRight: 15
    padLeft: 10
    padRight: 10
    background: Theme.moduleBgAlt
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["sh", "-c", "flatpak run com.ml4w.calendar"]);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Label {
        text: Qt.formatDateTime(clock.date, "hh:mm ddd")
    }
}
