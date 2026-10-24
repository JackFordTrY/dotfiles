import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// network: wifi "   {signalStrength}%", ethernet "  {ipaddr}", otherwise "{ifname}" or
// "Not connected" (max-length 50). Left click opens nmtui in kitty.
Module {
    id: root

    readonly property string status: NetworkInfo.state
    readonly property string text: {
        let text = NetworkInfo.ifname;
        if (status === "wifi")
            text = "   " + NetworkInfo.signalStrength + "%";
        else if (status === "ethernet")
            text = "  " + NetworkInfo.ipaddr;
        else if (status === "disconnected")
            text = "Not connected";
        return text.length > 50 ? text.slice(0, 49) + "…" : text;
    }

    visible: text !== ""
    pill: true
    marginRight: 15
    padLeft: 10
    padRight: 10
    background: status === "disconnected" ? Theme.dangerSoft : Theme.infoSoft
    tooltip: {
        if (status === "wifi")
            return "   " + NetworkInfo.essid + " (" + NetworkInfo.signalStrength + "%)";
        if (status === "ethernet")
            return "  " + NetworkInfo.ifname + " (" + NetworkInfo.ipaddr + "/" + NetworkInfo.cidr + ")";
        if (status === "disconnected")
            return "Disconnected";
        return " " + NetworkInfo.ifname + " via " + NetworkInfo.gwaddr;
    }
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["kitty", "-e", "nmtui"]);
    }

    Label {
        text: root.text
        color: root.status === "disconnected" ? Theme.red : root.status === "wifi" || root.status === "ethernet" ? Theme.text2 : Theme.blue
    }
}
