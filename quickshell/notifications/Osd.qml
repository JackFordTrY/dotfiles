pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The level after a volume, mic or brightness key, hanging from the middle of the top edge like
// the notification banners: it drips down on the first press, follows the key while it's held
// and pulls back up a moment after the last. The keybindings call `qs ipc call osd volume` (or
// `mic`, `brightness`) once they've changed it. Clicks go through it.
PanelWindow {
    id: root

    readonly property real bodyWidth: 300
    readonly property real bodyHeight: 48
    // volume | mic | brightness
    property string kind: "volume"
    property bool shown: false

    readonly property var node: kind === "mic" ? Audio.source : Audio.sink
    readonly property bool muted: kind !== "brightness" && (node?.audio?.muted ?? false)
    readonly property real level: kind === "brightness" ? Brightness.value : node?.audio?.volume ?? 0
    readonly property string icon: {
        if (kind === "brightness")
            return level < 0.34 ? "brightness_low" : level < 0.67 ? "brightness_medium" : "brightness_high";
        if (kind === "mic")
            return muted ? "mic_off" : "mic";
        return muted ? "volume_off" : level < 0.5 ? "volume_down" : "volume_up";
    }

    function show(what: string) {
        kind = what;
        shown = true;
        hide.restart();
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown || drop.height > 0.5
    anchors.top: true
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    // Room for the flares and the glow under it
    implicitWidth: bodyWidth + Theme.flare * 2 + 48
    implicitHeight: bodyHeight + 30
    color: "transparent"
    mask: Region {}

    IpcHandler {
        target: "osd"

        function volume(): void {
            root.show("volume");
        }

        function mic(): void {
            root.show("mic");
        }

        function brightness(): void {
            Brightness.refresh();
            root.show("brightness");
        }
    }

    Timer {
        id: hide

        interval: 1500
        onTriggered: root.shown = false
    }

    Item {
        id: drop

        x: (root.width - root.bodyWidth) / 2
        width: root.bodyWidth
        height: root.shown ? root.bodyHeight : 0

        Behavior on height {
            NumberAnimation {
                duration: root.shown ? 360 : 200
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.2
            }
        }

        EdgeShape {
            id: shape

            x: -Theme.flare
            bodyWidth: drop.width
            bodyHeight: drop.height
            radius: Theme.tabRadius + 6
            color: Theme.notificationBackground
            glowBehind: true

            // Hangs from the top edge
            transform: Scale {
                origin.y: shape.height / 2
                yScale: -1
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Row {
                x: 16
                y: (root.bodyHeight - height) / 2 + drop.height - root.bodyHeight
                width: root.bodyWidth - 32
                spacing: 12
                opacity: Math.max(0, (drop.height / root.bodyHeight - 0.6) / 0.4)

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.icon
                    fill: 1
                    color: root.muted ? Theme.red : Theme.text1
                }

                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - parent.spacing * 2 - 24 - 40
                    value: root.level
                    from: root.kind === "volume" ? Theme.purple0 : Theme.pink
                    to: root.kind === "brightness" ? Theme.yellow : root.kind === "mic" ? Theme.purple2 : Theme.blue
                    dimmed: root.muted
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: root.muted ? "Muted" : Math.round(root.level * 100) + "%"
                    color: root.muted ? Theme.textMuted : Theme.text2
                    font.pixelSize: root.muted ? 11 : 13
                }
            }
        }
    }
}
