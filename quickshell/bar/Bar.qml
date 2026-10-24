import QtQuick
import Quickshell
import qs.config
import qs.bar.modules

// window#waybar: bottom of every screen, 10px side margins, exclusive zone. The three module
// boxes are laid out like a GtkBox with a center widget: centred unless a side pushes it.
PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        left: true
        right: true
        bottom: true
    }
    margins {
        left: Theme.barMargin
        right: Theme.barMargin
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.barBackground
    }

    // border-bottom: drawn over the background, not part of the layout
    Rectangle {
        y: parent.height - 1
        width: parent.width
        height: 1
        color: Theme.moduleBorder
    }

    Row {
        id: leftModules

        height: parent.height

        Hardware {
            id: hardware
        }

        SpecialWorkspaces {
            id: special
        }

        WindowTitle {
            screen: bar.screen
            // Long titles ellipsize instead of pushing the workspaces off centre
            maxTextWidth: Math.floor((bar.width - center.width) / 2) - hardware.width - special.width - 37
        }
    }

    Workspaces {
        id: center

        x: Math.max(leftModules.width, Math.min(Math.floor((bar.width - width) / 2), bar.width - rightModules.width - width))
    }

    Row {
        id: rightModules

        x: bar.width - width
        height: parent.height

        Language {}
        Audio {}
        Bluetooth {}
        Battery {}
        Network {}
        Tray {}
        Power {}
        Clock {}
    }
}
