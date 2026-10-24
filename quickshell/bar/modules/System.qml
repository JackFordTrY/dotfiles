pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services
import qs.bar.controls

// The left tab: the robot and RAM in use, the title of what's playing, and the focused app's
// name at the right end. Hovering the robot or the RAM grows the tab into a panel with CPU,
// memory and disk gauges, a two-minute usage graph and the special workspace toggles; hovering
// the title shows the media page there instead (cover, timeline, controls), opening and closing
// in 125ms.
Popout {
    id: root

    required property ShellScreen screen

    readonly property var monitor: Hyprland.monitorFor(screen)
    property string activeSpecial: (monitor?.lastIpcObject?.specialWorkspace?.name ?? "").replace("special:", "")
    // system | media
    property string page: "system"
    // Which part of the row the pointer is over: the robot and RAM, or the title. Worked out from
    // the panel's own hover, which keeps up while the panel is open
    readonly property string hoveredPage: {
        if (!panelHovered || pointer.position.y < panel.height - Theme.tabHeight)
            return "";
        // The row sits 6px in from the panel's left
        const x = pointer.position.x - 6;
        if (x < memory.x + memory.width)
            return "system";
        if (media.visible && x >= media.x && x < media.x + media.width)
            return "media";
        return "";
    }
    // The media page needs a player
    readonly property string shownPage: page === "media" && !media.visible ? "system" : page

    function htop() {
        Quickshell.execDetached(["sh", "-c", "alacritty -e htop"]);
    }

    readonly property real pageHeight: shownPage === "media" ? mediaPage.implicitHeight : systemPage.implicitHeight
    // The bar's window is sized for the taller page, so switching never resizes it
    readonly property real maxHeight: Math.max(systemPage.implicitHeight, mediaPage.implicitHeight) + 28 + Theme.tabHeight

    expandedWidth: 420
    // Each page gets its own height; switching while open grows or shrinks the panel
    expandedHeight: pageHeight + 28 + Theme.tabHeight
    // The app name doesn't open the panel
    trigger: hoveredPage !== ""
    openDuration: hoveredPage === "media" ? 125 : Theme.openDuration
    closeDuration: shownPage === "media" ? 125 : Theme.closeDuration
    closeDelay: shownPage === "media" ? 125 : 250
    onHoveredPageChanged: {
        if (hoveredPage !== "")
            page = hoveredPage;
    }

    Behavior on expandedHeight {
        enabled: root.open

        NumberAnimation {
            duration: Theme.openDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasized
        }
    }

    // activespecial>>special:NAME,MONITOR (the name is empty once it's hidden)
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "activespecial")
                return;
            const comma = event.data.lastIndexOf(",");
            if (event.data.slice(comma + 1) === root.monitor?.name)
                root.activeSpecial = event.data.slice(0, comma).replace("special:", "");
        }
    }

    body: Item {
        x: 16
        y: 14
        width: root.openWidth - 32
        height: root.pageHeight

        PageSlot {
            shown: root.shownPage === "system"

            Column {
                id: systemPage

                width: parent.width
                spacing: 12

                Item {
                    width: parent.width
                    height: title.implicitHeight

                    SectionLabel {
                        id: title

                        text: "SYSTEM"
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.baseline: title.baseline
                        text: "up " + SystemStats.formatUptime(SystemStats.uptime)
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }

                Row {
                    width: parent.width

                    Resource {
                        icon: "memory"
                        label: "CPU"
                        value: SystemStats.cpu
                        detail: "load " + SystemStats.loadAverage.split(" ")[0]
                        from: Theme.purple0
                        to: Theme.blue
                        tooltip: SystemStats.cpuCores.map((u, i) => "Core " + i + "  " + Math.round(u * 100) + "%").join("\n")
                    }

                    Resource {
                        icon: "memory_alt"
                        label: "RAM"
                        value: SystemStats.memory
                        detail: SystemStats.formatBytes(SystemStats.memoryUsed).replace(" GiB", "") + " / " + SystemStats.formatBytes(SystemStats.memoryTotal)
                        from: Theme.blue
                        to: Theme.cyan
                        tooltip: SystemStats.formatBytes(SystemStats.memoryUsed) + " used of " + SystemStats.formatBytes(SystemStats.memoryTotal)
                    }

                    Resource {
                        icon: "hard_drive"
                        label: "DISK"
                        value: SystemStats.disk
                        detail: SystemStats.formatBytes(SystemStats.diskTotal - SystemStats.diskUsed) + " free"
                        from: Theme.pink
                        to: Theme.purple2
                        tooltip: SystemStats.formatBytes(SystemStats.diskUsed) + " used of " + SystemStats.formatBytes(SystemStats.diskTotal) + " on /"
                    }
                }

                Item {
                    width: parent.width
                    height: 76

                    Row {
                        id: legend

                        spacing: 14

                        LegendEntry {
                            label: "CPU"
                            value: SystemStats.cpu
                            from: Theme.purple0
                            to: Theme.blue
                        }

                        LegendEntry {
                            label: "RAM"
                            value: SystemStats.memory
                            from: Theme.blue
                            to: Theme.cyan
                        }
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.verticalCenter: legend.verticalCenter
                        text: "last 2 min"
                        color: Theme.textDim
                        font.pixelSize: 11
                    }

                    Item {
                        id: graphArea

                        y: legend.height + 8
                        width: parent.width
                        height: parent.height - y

                        Repeater {
                            model: [0, 0.5, 1]

                            Rectangle {
                                required property real modelData

                                y: Math.round(modelData * (graphArea.height - 1))
                                width: graphArea.width
                                height: 1
                                color: Theme.surface4
                                opacity: modelData === 1 ? 1 : 0.6
                            }
                        }

                        HistoryGraph {
                            anchors.fill: parent
                            capacity: SystemStats.historyLength
                            values: SystemStats.memoryHistory
                            from: Theme.blue
                            to: Theme.cyan
                            areaOpacity: 0.12
                        }

                        HistoryGraph {
                            anchors.fill: parent
                            capacity: SystemStats.historyLength
                            values: SystemStats.cpuHistory
                            from: Theme.purple0
                            to: Theme.blue
                            lineWidth: 2
                        }
                    }
                }

                // The special workspaces, lit while showing
                Row {
                    spacing: 6

                    Repeater {
                        model: [
                            {
                                name: "kitty",
                                icon: "terminal",
                                label: "Kitty"
                            },
                            {
                                name: "ytmusic",
                                icon: "music_note",
                                label: "Music"
                            },
                            {
                                name: "trash",
                                icon: "delete",
                                label: "Trash"
                            }
                        ]

                        Chip {
                            required property var modelData

                            icon: modelData.icon
                            text: modelData.label
                            active: root.activeSpecial === modelData.name
                            onClicked: Hyprland.dispatch("togglespecialworkspace " + modelData.name)
                        }
                    }
                }
            }
        }

        PageSlot {
            shown: root.shownPage === "media"

            MediaPage {
                id: mediaPage

                anchors.fill: parent
                active: root.open && root.shownPage === "media"
            }
        }
    }

    // Bottom edge: the closed tab's contents stay put while the panel grows around them
    TabItem {
        id: robot

        icon: "smart_toy"
        active: root.open && root.shownPage === "system"
        onClicked: button => {
            if (button === Qt.LeftButton)
                root.htop();
        }
    }

    Memory {
        id: memory
    }

    Divider {
        visible: media.visible
    }

    NowPlaying {
        id: media

        pinned: root.open && root.page === "media"
    }

    Divider {
        visible: windowTitle.visible
    }

    // The app name, at the right end
    WindowTitle {
        id: windowTitle

        screen: root.screen
    }

    component Resource: Item {
        id: resource

        property string icon
        property string label
        property real value
        property string detail
        property alias from: gauge.from
        property alias to: gauge.to
        property string tooltip

        width: systemPage.width / 3
        height: gauge.height + detailText.implicitHeight + 4

        CircularGauge {
            id: gauge

            anchors.horizontalCenter: parent.horizontalCenter
            size: 84
            value: resource.value

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 17
                text: resource.icon
                fill: hover.hovered ? 1 : 0
                color: hover.hovered ? Theme.text1 : Theme.text2
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 35
                text: Math.round(resource.value * 100) + "%"
                font.pixelSize: 16
                font.bold: true
            }

            // Sits in the ring's opening
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 64
                text: resource.label
                color: Theme.textMuted
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }
        }

        StyledText {
            id: detailText

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: gauge.bottom
            anchors.topMargin: 4
            text: resource.detail
            color: Theme.textMuted
            font.pixelSize: 11
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.htop()
        }

        Tooltip {
            target: gauge
            text: resource.tooltip
            hovered: hover.hovered
            pointerX: gauge.width / 2
        }
    }

    component LegendEntry: Row {
        id: entry

        property string label
        property real value
        property color from
        property color to

        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 3
            radius: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: entry.from
                }
                GradientStop {
                    position: 1
                    color: entry.to
                }
            }
        }

        StyledText {
            text: entry.label + " " + Math.round(entry.value * 100) + "%"
            color: Theme.text2
            font.pixelSize: 11
        }
    }
}
