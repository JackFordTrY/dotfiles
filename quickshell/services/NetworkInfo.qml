pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Network state as Waybar's network module derives it: the default-route interface, its IPv4
// address and, for Wi-Fi, the associated BSS from the nl80211 scan cache (re-read every 60s).
Singleton {
    id: root

    // disabled | disconnected | linked | ethernet | wifi
    property string state: "disconnected"
    property string ifname
    property string ipaddr
    property int cidr
    property string gwaddr
    property string essid
    property int signalStrength

    property string wifiIf

    function refresh() {
        links.running = true;
    }

    function parseLinks(text: string) {
        const [routes, addrs, devices, rfkill] = text.split("@@\n");
        const route = JSON.parse(routes || "[]").filter(r => r.dev).sort((a, b) => (a.metric ?? 0) - (b.metric ?? 0))[0];
        // "<ifname> <carrier>[ wireless]"
        const device = (route && devices.split("\n").find(l => l.split(" ")[0] === route.dev)) || "";
        if (device.split(" ")[1] !== "1") {
            const blocked = rfkill.split("\n").some(l => /^wlan (1 \d|\d 1)$/.test(l));
            root.state = blocked ? "disabled" : "disconnected";
            root.ifname = root.ipaddr = root.gwaddr = root.essid = "";
            root.signalStrength = 0;
            return;
        }
        const info = JSON.parse(addrs || "[]").find(a => a.ifname === route.dev);
        const v4 = info?.addr_info?.find(a => a.family === "inet");
        root.ifname = route.dev;
        root.gwaddr = route.gateway ?? "";
        root.ipaddr = v4?.local ?? "";
        root.cidr = v4?.prefixlen ?? 0;
        if (device.endsWith(" wireless")) {
            root.wifiIf = route.dev;
            wifi.running = true;
        } else {
            root.essid = "";
            root.signalStrength = 0;
            root.updateState();
        }
    }

    function parseWifi(text: string) {
        const bss = text.split(/^BSS /m).find(b => /^\S+\(on \S+\) -- associated/.test(b)) ?? "";
        const ssid = bss.match(/^\s*SSID: (.*)$/m);
        const signal = bss.match(/^\s*signal: (-?[\d.]+) dBm$/m);
        root.essid = ssid ? ssid[1] : "";
        if (signal) {
            // Waybar: 100 - |dBm - (-45)| / 45 * 100, clamped to 0..100
            const dbm = Math.trunc(parseFloat(signal[1]));
            root.signalStrength = Math.min(100, Math.max(0, Math.trunc(100 - Math.abs(dbm + 45) / 45 * 100)));
        }
        root.updateState();
    }

    function updateState() {
        root.state = root.ipaddr === "" ? "linked" : root.essid === "" ? "ethernet" : "wifi";
    }

    Process {
        id: links

        command: ["sh", "-c", "ip -j -4 route show default; echo @@; ip -j -4 addr show; echo @@; " + "for d in /sys/class/net/*; do printf '%s %s%s\\n' \"${d##*/}\" \"$(cat \"$d/carrier\" 2>/dev/null || echo 0)\" " + "\"$([ -d \"$d/wireless\" ] && echo ' wireless')\"; done; echo @@; " + "for r in /sys/class/rfkill/rfkill*; do echo \"$(cat \"$r/type\") $(cat \"$r/soft\") $(cat \"$r/hard\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.parseLinks(text)
        }
    }

    Process {
        id: wifi

        command: ["iw", "dev", root.wifiIf, "scan", "dump"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWifi(text)
        }
    }

    // Netlink link/address/route changes, like Waybar's RTM_* event handling
    Process {
        running: true
        command: ["ip", "monitor", "link", "address", "route"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce

        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
