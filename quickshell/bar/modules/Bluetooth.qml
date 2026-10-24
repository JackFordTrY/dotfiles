import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components

// bluetooth: default format " {status}"; the off/disabled/no-controller formats are empty,
// which hides the module. Left click opens blueman-manager.
Module {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property string status: {
        if (!adapter)
            return "no-controller";
        if (adapter.state === BluetoothAdapterState.Blocked)
            return "disabled";
        if (!adapter.enabled)
            return "off";
        return adapter.devices.values.some(d => d.connected) ? "connected" : "on";
    }

    visible: status === "on" || status === "connected"
    pill: true
    marginRight: 15
    padLeft: 10
    padRight: 10
    background: Theme.moduleBg
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["blueman-manager"]);
    }

    Label {
        text: " " + root.status
        color: Theme.text2
    }
}
