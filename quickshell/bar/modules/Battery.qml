import QtQuick
import qs.config
import qs.components
import qs.services

// battery: "{icon} {capacity}%" (charging/plugged have their own formats), left click toggles
// format-alt "{icon} {time}". Critical (<=15%) while not charging blinks red.
Module {
    id: root

    property bool alt: false
    // Waybar's CSS class: status lowercased with spaces as dashes
    readonly property string status: BatteryInfo.status.toLowerCase().replace(/ /g, "-")
    readonly property bool critical: BatteryInfo.capacity <= 15 && status !== "charging"
    readonly property bool charged: status === "charging" || status === "plugged"

    readonly property string time: {
        const hours = Math.abs(BatteryInfo.timeRemaining);
        const h = Math.trunc(hours);
        const m = Math.trunc(60 * (hours - h));
        return h === 0 && m === 0 ? "" : h + " h " + m + " min";
    }
    readonly property string icon: [" ", " ", " ", " ", " "][Math.min(4, Math.trunc(BatteryInfo.capacity / 20))]
    readonly property string text: {
        if (status === "charging")
            return " " + BatteryInfo.capacity + "%";
        if (status === "plugged")
            return " " + BatteryInfo.capacity + "%";
        return icon + " " + (alt ? time : BatteryInfo.capacity + "%");
    }

    // @keyframes blink: 0.5s linear, infinite, alternate, towards modulebg/textcolor2
    property real blink: 0

    function mix(from: color, to: color, t: real): color {
        return Qt.rgba(from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t, from.b + (to.b - from.b) * t, from.a + (to.a - from.a) * t);
    }

    visible: BatteryInfo.present
    pill: true
    marginRight: 15
    padLeft: 10
    padRight: 15
    background: critical ? mix(Theme.red, Theme.moduleBg, blink) : charged ? Theme.successSoft : Theme.moduleBg
    tooltip: BatteryInfo.timeRemaining !== 0 ? (BatteryInfo.timeRemaining > 0 ? "Empty in " : "Full in ") + time : BatteryInfo.status
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

    Label {
        text: root.text
        color: root.critical ? root.mix(Theme.text1, Theme.text2, root.blink) : Theme.text2
    }
}
