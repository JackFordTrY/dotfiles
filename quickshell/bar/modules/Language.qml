import QtQuick
import Quickshell
import qs.components
import qs.services

// The active keyboard layout as ENG / RU / UA; left click switches to the next one.
TabItem {
    text: KeyboardLayout.short
    tooltip: KeyboardLayout.layout
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }
}
