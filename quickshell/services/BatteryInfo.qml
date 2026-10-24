pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery capacity, status and time remaining read from sysfs with Waybar's battery module
// logic (status priorities, "Plugged" detection, 100% => "Full"). UPower changes and a 60s
// interval trigger re-reads.
Singleton {
    id: root

    property bool present: false
    property int capacity: 0
    // Waybar's status string: Full, Charging, Discharging, Plugged, Not charging, Unknown
    property string status: "Unknown"
    // Hours; positive = to empty, negative = to full
    property real timeRemaining: 0

    function refresh() {
        probe.running = true;
    }

    function parse(text: string) {
        const supplies = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^\/sys\/class\/power_supply\/([^/]+)\/(\w+):(.*)$/);
            if (!m)
                continue;
            supplies[m[1]] = supplies[m[1]] ?? {};
            supplies[m[1]][m[2]] = m[3];
        }
        const names = Object.keys(supplies).sort();
        const batteries = names.filter(n => supplies[n].type === "Battery" && supplies[n].scope !== "Device");
        const adapter = names.map(n => supplies[n]).find(s => s.type === "Mains");
        root.present = batteries.length > 0;
        if (!root.present)
            return;

        // Unknown > Full > Not charging > Discharging > Charging
        const rank = ["Charging", "Discharging", "Not charging", "Full", "Unknown"];
        let status = "Unknown", capacity = 0, energy = 0, energyFull = 0, power = 0;
        let hasCapacity = false, timeToEmpty = 0, timeToFull = 0;
        for (const [i, name] of batteries.entries()) {
            const b = supplies[name];
            const s = b.status ?? "Unknown";
            if (i === 0 || rank.indexOf(s) < rank.indexOf(status))
                status = s;
            if (b.capacity !== undefined) {
                hasCapacity = true;
                capacity += Number(b.capacity);
            }
            energy += Number(b.energy_now ?? b.charge_now ?? 0);
            energyFull += Number(b.energy_full ?? b.charge_full ?? 0);
            power += Math.abs(Number(b.power_now ?? b.current_now ?? 0));
            timeToEmpty += Number(b.time_to_empty_now ?? 0);
            timeToFull += Number(b.time_to_full_now ?? 0);
        }

        // Plugged has priority over Not charging (e.g. TLP charge thresholds)
        if (adapter && (status === "Discharging" || status === "Not charging") && adapter.online === "1" && adapter.status !== "Discharging")
            status = "Plugged";

        let time = 0;
        if (status === "Discharging")
            time = timeToEmpty ? timeToEmpty / 3600 : power ? energy / power : 0;
        else if (status === "Charging")
            time = Math.min(0, timeToFull ? -timeToFull / 3600 : power ? -(energyFull - energy) / power : 0);

        let percent = hasCapacity ? capacity / batteries.length : energyFull ? energy * 100 / energyFull : 0;
        const cap = Math.round(Math.min(100, percent));
        if (cap === 100 && status === "Charging")
            status = "Full";
        if (status === "Unknown")
            status = cap === 100 ? "Full" : adapter?.online === "1" && adapter?.status !== "Discharging" ? "Plugged" : "Discharging";

        root.capacity = cap;
        root.status = status;
        root.timeRemaining = time;
    }

    Process {
        id: probe

        command: ["sh", "-c", "grep -H . /sys/class/power_supply/*/type /sys/class/power_supply/*/scope " + "/sys/class/power_supply/*/status /sys/class/power_supply/*/online /sys/class/power_supply/*/capacity " + "/sys/class/power_supply/*/energy_now /sys/class/power_supply/*/energy_full " + "/sys/class/power_supply/*/charge_now /sys/class/power_supply/*/charge_full " + "/sys/class/power_supply/*/power_now /sys/class/power_supply/*/current_now " + "/sys/class/power_supply/*/time_to_empty_now /sys/class/power_supply/*/time_to_full_now 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Connections {
        target: UPower.displayDevice

        function onPercentageChanged() {
            root.refresh();
        }
        function onStateChanged() {
            root.refresh();
        }
    }

    Connections {
        target: UPower

        function onOnBatteryChanged() {
            root.refresh();
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
