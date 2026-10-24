import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// group/hardware: the system icon; hovering slides disk/cpu/memory out on its left.
Drawer {
    id: root

    function htop(button: int) {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["sh", "-c", "alacritty -e htop"]);
    }

    leftToRight: false

    // custom/system: 20px bold, Pango falls back to Font Awesome 7 Solid for the glyph
    leader: Module {
        marginLeft: 15
        marginRight: 15

        Label {
            text: ""
            size: 20
            bold: true
            baselineY: Theme.baseline(0, Theme.barHeight, 20, false, true)
        }
    }

    Module {
        tooltip: SystemStats.diskTooltip
        onClicked: button => root.htop(button)

        Label {
            text: "D " + SystemStats.diskPercent + "% "
            baselineY: Theme.labelBaseline
        }
    }

    Module {
        tooltip: SystemStats.cpuTooltip
        onClicked: button => root.htop(button)

        Label {
            text: "/ C " + SystemStats.cpuUsage + "% "
            baselineY: Theme.labelBaseline
        }
    }

    Module {
        tooltip: SystemStats.memoryUsedGiB.toFixed(1) + "GiB used"
        onClicked: button => root.htop(button)

        Label {
            text: "/ M " + SystemStats.memoryPercent + "% "
            baselineY: Theme.labelBaseline
        }
    }
}
