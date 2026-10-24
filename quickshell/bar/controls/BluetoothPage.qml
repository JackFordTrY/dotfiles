pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components

// Paired devices, plus nearby ones while scanning. Clicking connects or disconnects a paired
// device and pairs (then connects) a new one.
Column {
    id: root

    // Scanning stops once this goes false
    property bool active
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.paired || (adapter.discovering && d.deviceName !== "")).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    // BlueZ icon names to Material Symbols
    function deviceIcon(icon: string): string {
        const icons = {
            "audio-headset": "headset_mic",
            "audio-headphones": "headphones",
            "audio-card": "speaker",
            "input-mouse": "mouse",
            "input-keyboard": "keyboard",
            "input-gaming": "sports_esports",
            "input-tablet": "tablet",
            "phone": "smartphone",
            "computer": "computer",
            "camera-video": "videocam",
            "printer": "print"
        };
        return icons[icon] ?? "bluetooth";
    }

    function activate(device: BluetoothDevice) {
        if (device.connected)
            device.disconnect();
        else if (device.paired)
            device.connect();
        else
            device.pair();
    }

    spacing: 6
    onActiveChanged: {
        if (!active && adapter?.discovering)
            adapter.discovering = false;
    }

    Item {
        width: parent.width
        height: label.implicitHeight

        SectionLabel {
            id: label

            text: "DEVICES"
        }

        // Scan toggle
        Row {
            id: scan

            visible: root.powered
            anchors.right: parent.right
            anchors.verticalCenter: label.verticalCenter
            spacing: 4

            MaterialIcon {
                id: radar

                anchors.verticalCenter: parent.verticalCenter
                text: "radar"
                size: 16
                fill: scanArea.containsMouse ? 1 : 0
                color: root.adapter?.discovering ? Theme.accent : scanArea.containsMouse ? Theme.text1 : Theme.textMuted

                RotationAnimation on rotation {
                    running: root.adapter?.discovering ?? false
                    from: 0
                    to: 360
                    duration: 1600
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        radar.rotation = 0
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.adapter?.discovering ? "Scanning…" : "Scan"
                color: root.adapter?.discovering ? Theme.accent : scanArea.containsMouse ? Theme.text1 : Theme.textMuted
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: scanArea

            visible: scan.visible
            anchors.fill: scan
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: root.adapter.discovering = !root.adapter.discovering
        }
    }

    StyledText {
        visible: !root.powered
        text: root.adapter?.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked" : "Bluetooth is off"
        color: Theme.textDim
        font.pixelSize: 13
    }

    StyledText {
        visible: root.powered && root.devices.length === 0
        text: root.adapter?.discovering ? "Looking for devices…" : "No paired devices"
        color: Theme.textDim
        font.pixelSize: 13
    }

    // Fills the rest of the page, then scrolls
    Flickable {
        visible: root.powered && root.devices.length > 0
        width: parent.width
        height: Math.min(list.height, root.height - y)
        contentHeight: list.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: root.devices
                }

                ListEntry {
                    id: entry

                    required property BluetoothDevice modelData
                    readonly property bool changing: modelData?.pairing || modelData?.state === BluetoothDeviceState.Connecting || modelData?.state === BluetoothDeviceState.Disconnecting

                    icon: root.deviceIcon(modelData?.icon ?? "")
                    text: modelData?.name || modelData?.deviceName || ""
                    active: modelData?.connected ?? false
                    busy: changing
                    detail: {
                        if (modelData?.pairing)
                            return "Pairing…";
                        if (modelData?.state === BluetoothDeviceState.Connecting)
                            return "Connecting…";
                        if (modelData?.state === BluetoothDeviceState.Disconnecting)
                            return "Disconnecting…";
                        if (modelData?.connected)
                            return modelData?.batteryAvailable ? Math.round(modelData?.battery * 100) + "%" : "Connected";
                        return modelData?.paired ? "" : "Pair";
                    }
                    onClicked: button => {
                        if (button === Qt.LeftButton)
                            root.activate(modelData);
                    }

                    // A freshly paired device is trusted and connected straight away
                    Connections {
                        target: entry.modelData

                        function onPairedChanged() {
                            if (entry.modelData?.paired) {
                                entry.modelData.trusted = true;
                                entry.modelData.connect();
                            }
                        }
                    }
                }
            }
        }
    }
}
