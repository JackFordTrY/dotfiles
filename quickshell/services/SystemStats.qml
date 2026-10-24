pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and disk figures computed exactly as Waybar's cpu (10s), memory (30s) and
// disk (30s, path "/") modules do, including their default tooltips.
Singleton {
    id: root

    property int cpuUsage: 0
    property string cpuTooltip: "(pending)"
    property int memoryPercent: 0
    property real memoryUsedGiB: 0
    property int diskPercent: 0
    property string diskTooltip: ""

    property var prevCpuTimes: []

    // Waybar's pow_format(bytes, "B", binary): "{:.1f}" + Ki/Mi/Gi/... + "B"
    function formatBytes(bytes: real): string {
        const units = ["", "k", "M", "G", "T", "P"];
        let pow = 0;
        while (pow + 1 < units.length && bytes / 1024 >= 1) {
            bytes /= 1024;
            pow++;
        }
        return bytes.toFixed(1) + units[pow] + (pow ? "i" : "") + "B";
    }

    function parseCpuTimes(text: string): var {
        const times = [];
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                break;
            const t = line.slice(5).trim().split(/\s+/).map(Number);
            times.push(t.length >= 5 ? [t[3] + t[4], t.reduce((a, b) => a + b, 0)] : [0, 0]);
        }
        return times;
    }

    function updateCpu(text: string) {
        const curr = parseCpuTimes(text);
        const prev = prevCpuTimes;
        prevCpuTimes = curr;
        if (prev.length !== curr.length)
            return;
        if (prev.length === 0 || curr[0][1] === prev[0][1])
            return;
        const usage = curr.map((c, i) => Math.trunc(100 * (1 - (c[0] - prev[i][0]) / (c[1] - prev[i][1]))));
        cpuUsage = usage[0];
        cpuTooltip = ["Total: " + usage[0] + "%"].concat(usage.slice(1).map((u, i) => "Core" + i + ": " + u + "%")).join("\n");
    }

    function updateMemory(text: string) {
        const info = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                info[m[1]] = Number(m[2]);
        }
        const used = info.MemTotal - (info.MemAvailable ?? info.MemFree);
        memoryPercent = Math.trunc(100 * used / info.MemTotal);
        memoryUsedGiB = used / 1024 / 1024;
    }

    // Loads on creation (Waybar's priming read), then on each reload()
    FileView {
        id: procStat

        path: "/proc/stat"
        onLoaded: root.updateCpu(text())
    }

    FileView {
        id: procMeminfo

        path: "/proc/meminfo"
        onLoaded: root.updateMemory(text())
    }

    // Waybar's first CPU figure comes 100ms after the priming read, then every 10s
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            interval = 10000;
            procStat.reload();
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procMeminfo.reload();
            disk.running = true;
        }
    }

    Process {
        id: disk

        // f_blocks f_bfree f_bavail f_frsize
        command: ["stat", "-f", "-c", "%b %f %a %S", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [blocks, free, avail, size] = text.trim().split(" ").map(Number);
                root.diskPercent = Math.trunc((blocks - free) * 100 / blocks);
                root.diskTooltip = root.formatBytes((blocks - free) * size) + " used out of " + root.formatBytes(blocks * size) + " on / (" + root.diskPercent + "%)";
            }
        }
    }
}
