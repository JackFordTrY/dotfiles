import QtQuick
import qs.config
import qs.components
import qs.services

// Connection state as an icon (wifi bars follow the signal strength); the Wi-Fi page of the
// controls panel has the networks.
TabItem {
    readonly property string status: NetworkInfo.state

    icon: {
        switch (status) {
        case "wifi":
            {
                const s = NetworkInfo.signalStrength;
                return s >= 75 ? "signal_wifi_4_bar" : "network_wifi_" + (s >= 50 ? 3 : s >= 25 ? 2 : 1) + "_bar";
            }
        case "ethernet":
            return "lan";
        case "linked":
            return "link";
        case "disabled":
            return "wifi_off";
        default:
            return "signal_wifi_off";
        }
    }
    iconColor: status === "disconnected" ? Theme.red : status === "linked" ? Theme.blue : status === "disabled" ? Theme.textDim : Theme.text2
}
