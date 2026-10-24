import QtQuick
import Quickshell.Bluetooth
import qs.components

// Shown while the adapter is on; the Bluetooth page of the controls panel has the devices.
TabItem {
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    visible: (adapter?.enabled ?? false) && adapter.state !== BluetoothAdapterState.Blocked
    icon: adapter?.devices.values.some(d => d.connected) ? "bluetooth_connected" : "bluetooth"
}
