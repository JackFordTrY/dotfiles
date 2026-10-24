import QtQuick
import Quickshell
import qs.services

// A notification when the battery runs down to 15%, and an urgent one (staying up until
// dismissed) at 5%. Each warns once per discharge; plugging in starts over.
Scope {
    id: root

    // The lowest level warned about since the charger was unplugged
    property int warned: 101

    function check() {
        if (!BatteryInfo.present)
            return;
        if (BatteryInfo.status !== "Discharging") {
            warned = 101;
            return;
        }
        const level = BatteryInfo.capacity;
        if (level <= 5 && warned > 5) {
            warned = 5;
            notify("critical", "battery-caution", "Battery at " + level + "%", "Plug in now: the laptop will shut down soon" + left());
        } else if (level <= 15 && warned > 15) {
            warned = 15;
            notify("normal", "battery-low", "Battery at " + level + "%", "Time to find a charger" + left());
        }
    }

    // ", about 1 h 20 min left"
    function left(): string {
        const hours = BatteryInfo.timeRemaining;
        if (hours <= 0)
            return "";
        const minutes = Math.round(hours * 60);
        return ", about " + (minutes >= 60 ? Math.floor(minutes / 60) + " h " : "") + minutes % 60 + " min left";
    }

    function notify(urgency: string, icon: string, summary: string, body: string) {
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, "-i", icon, summary, body]);
    }

    // Already low when the shell starts
    Component.onCompleted: check()

    Connections {
        target: BatteryInfo

        function onCapacityChanged() {
            root.check();
        }

        function onStatusChanged() {
            root.check();
        }
    }
}
