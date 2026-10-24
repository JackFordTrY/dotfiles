pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and disk usage for the system popout. CPU and memory are sampled every 2s, keeping
// the last two minutes for the history graphs; disk usage of / is read every 30s.
Singleton {
    id: root

    readonly property int historyLength: 60
    readonly property int interval: 2000

    // Fractions 0-1
    property real cpu: 0
    property var cpuCores: []
    property var cpuHistory: []
    property real memory: 0
    property var memoryHistory: []
    property real disk: 0

    // Bytes
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0

    property real uptime: 0
    property string loadAverage: ""

    property var prevCpuTimes: []

    function formatBytes(bytes: real): string {
        const gib = bytes / Math.pow(1024, 3);
        return gib >= 1024 ? (gib / 1024).toFixed(1) + " TiB" : gib.toFixed(gib >= 100 ? 0 : 1) + " GiB";
    }

    function formatUptime(seconds: real): string {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
    }

    function push(history: var, value: real): var {
        return history.slice(1 - historyLength).concat([value]);
    }

    // Per line of /proc/stat: [idle + iowait, total]
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
        if (prev.length !== curr.length || prev.length === 0 || curr[0][1] === prev[0][1])
            return;
        const usage = curr.map((c, i) => Math.max(0, 1 - (c[0] - prev[i][0]) / (c[1] - prev[i][1])));
        cpu = usage[0];
        cpuCores = usage.slice(1);
        cpuHistory = push(cpuHistory, cpu);
    }

    function updateMemory(text: string) {
        const info = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                info[m[1]] = Number(m[2]) * 1024;
        }
        memoryTotal = info.MemTotal;
        memoryUsed = info.MemTotal - (info.MemAvailable ?? info.MemFree);
        memory = memoryUsed / memoryTotal;
        memoryHistory = push(memoryHistory, memory);
    }

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

    FileView {
        id: procUptime

        path: "/proc/uptime"
        onLoaded: root.uptime = parseFloat(text())
    }

    FileView {
        id: procLoadavg

        path: "/proc/loadavg"
        onLoaded: root.loadAverage = text().split(" ").slice(0, 3).join(" ")
    }

    // The first CPU figure needs a second /proc/stat read shortly after the priming one
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            interval = root.interval;
            procStat.reload();
            procMeminfo.reload();
            procUptime.reload();
            procLoadavg.reload();
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskStat.running = true
    }

    Process {
        id: diskStat

        // f_blocks f_bfree f_frsize
        command: ["stat", "-f", "-c", "%b %f %S", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [blocks, free, size] = text.trim().split(" ").map(Number);
                root.diskTotal = blocks * size;
                root.diskUsed = (blocks - free) * size;
                root.disk = root.diskUsed / root.diskTotal;
            }
        }
    }
}
