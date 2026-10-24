pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The screen's backlight through brightnessctl. sysfs says nothing when it changes, so `refresh()`
// re-reads it (the OSD after a brightness key, the controls panel when it opens). `set()` while
// one write is running queues the latest value, so a dragged slider doesn't pile up processes.
Singleton {
    id: root

    property bool available: false
    // 0..1
    property real value: 0
    // The level waiting for the running write to finish, or -1
    property real pending: -1

    function refresh() {
        reader.running = true;
    }

    // Never quite off: a black screen can't be turned back up from the slider
    function set(level: real) {
        value = Math.max(0.01, Math.min(1, level));
        if (writer.running) {
            pending = value;
            return;
        }
        writer.command = ["brightnessctl", "-m", "s", Math.round(value * 100) + "%"];
        writer.running = true;
    }

    // "amdgpu_bl1,backlight,121,47%,255"
    function parse(text: string) {
        const fields = text.trim().split(",");
        if (fields.length < 5)
            return;
        available = true;
        if (!writer.running && pending < 0)
            value = Number(fields[2]) / Number(fields[4]);
    }

    Component.onCompleted: refresh()

    Process {
        id: reader

        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: writer

        onExited: {
            if (root.pending >= 0) {
                const level = root.pending;
                root.pending = -1;
                root.set(level);
            }
        }
    }
}
