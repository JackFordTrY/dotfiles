import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.bar.modules

// Three tabs standing on the bottom screen edge, with nothing behind them. The window is taller than
// the 44px it reserves so the side tabs can grow into panels; the input mask covers only the
// band and the panels, so clicks above them reach the windows behind.
PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        left: true
        right: true
        bottom: true
    }
    exclusiveZone: Theme.barHeight
    // Room for the taller panel and the glow above it
    implicitHeight: Math.max(system.maxHeight, controls.maxHeight) + 24
    color: "transparent"
    // Only while a Wi-Fi password is being typed
    WlrLayershell.keyboardFocus: controls.wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Region's `item` doesn't follow an item that grows or moves, so the panels' geometry is
    // bound by hand, in window coordinates
    mask: Region {
        y: band.y
        width: band.width
        height: band.height

        Region {
            x: system.x + system.panel.x
            y: band.y + system.panel.y
            width: system.panel.width
            height: system.panel.height
        }

        Region {
            x: controls.x + controls.panel.x
            y: band.y + controls.panel.y
            width: controls.panel.width
            height: controls.panel.height
        }
    }

    Item {
        id: band

        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.barHeight

        System {
            id: system

            x: Theme.edgePadding + Theme.flare
            screen: bar.screen
            // The panels grow over the workspaces
            z: 1
        }

        // Centred unless a side pushes it
        Workspaces {
            id: center

            x: Math.max(system.x + system.width + Theme.tabGap, Math.min(Math.floor((band.width - width) / 2), controls.x - Theme.tabGap - width))
        }

        Controls {
            id: controls

            x: band.width - width - Theme.edgePadding - Theme.flare
            z: 1
        }
    }
}
