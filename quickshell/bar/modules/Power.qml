import QtQuick
import Quickshell
import qs.config
import qs.components

// custom/exit: power icon, left click opens the rofi power menu.
Module {
    marginRight: 20
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["sh", "-c", "rofi -show powermenu -modi powermenu:~/.config/rofi/rofi_power_menu.sh"]);
    }

    Label {
        text: ""
        size: 20
        baselineY: Theme.baseline(0, Theme.barHeight, 20, true, false)
    }
}
