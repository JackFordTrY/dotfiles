import QtQuick
import qs.config
import qs.components
import qs.services

// Charge level, with the time left on left click. Charging turns it green; at 15% or less while
// discharging it blinks red.
TabItem {
    id: root

    property bool alt: false
    readonly property string status: BatteryInfo.status.toLowerCase()
    readonly property int capacity: BatteryInfo.capacity
    readonly property bool charging: status === "charging"
    readonly property bool plugged: status === "plugged" || status === "full"
    readonly property bool critical: capacity <= 15 && !charging && !plugged

    readonly property string time: {
        const hours = Math.abs(BatteryInfo.timeRemaining);
        const h = Math.trunc(hours);
        const m = Math.trunc(60 * (hours - h));
        return h === 0 && m === 0 ? "" : h + "h " + m + "m";
    }

    // @keyframes blink: 0.5s each way
    property real blink: 0

    visible: BatteryInfo.present
    icon: {
        if (charging)
            return capacity >= 95 ? "battery_charging_full" : "battery_charging_" + [20, 30, 50, 60, 80, 90].reduce((a, t) => capacity >= t ? t : a, 20);
        if (plugged)
            return "power";
        if (critical)
            return "battery_alert";
        return capacity >= 95 ? "battery_full" : "battery_" + Math.round(capacity / 100 * 6) + "_bar";
    }
    text: alt && time !== "" ? time : capacity + "%"
    iconColor: critical ? Theme.mix(Theme.red, Theme.text2, blink) : charging || plugged ? Theme.green : Theme.text2
    textColor: critical ? Theme.mix(Theme.red, Theme.text2, blink) : Theme.text2
    accentColor: charging || plugged ? Theme.green : Theme.accent
    tooltip: BatteryInfo.timeRemaining !== 0 && time !== "" ? (BatteryInfo.timeRemaining > 0 ? "Empty in " : "Full in ") + time : BatteryInfo.status
    onClicked: button => {
        if (button === Qt.LeftButton)
            alt = !alt;
    }

    SequentialAnimation on blink {
        running: root.critical
        loops: Animation.Infinite

        NumberAnimation {
            from: 0
            to: 1
            duration: 500
        }

        NumberAnimation {
            from: 1
            to: 0
            duration: 500
        }
    }
}
