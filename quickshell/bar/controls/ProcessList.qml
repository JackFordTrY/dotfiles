pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Your five processes using the most CPU, measured by top over a second and again every couple
// of seconds while `active` (the panel is open on the system page). The cross ends one with a
// second click to confirm; the session's own processes (Hyprland, the shell, audio) don't get
// one.
Column {
    id: root

    property bool active
    // { pid, name, cpu (percent of a core), memory (KiB) }, busiest first
    property var processes: []
    // The process waiting for its confirming click
    property int confirming: 0
    // top's 15-character names of what the session can't do without
    readonly property var essential: ["Hyprland", "qs", "quickshell", ".quickshell-wra", "pipewire", "pipewire-pulse", "wireplumber", "Xwayland", "systemd", "dbus-daemon", "dbus-broker", "hyprpaper", "hyprpolkitagent", "xdg-desktop-por", "wl-paste"]

    // "417488" KiB, or "1.9g" when the column runs out of room
    function kibOf(text: string): real {
        const match = text.match(/^([\d.]+)([kmgtp]?)$/);
        return match ? Number(match[1]) * Math.pow(1024, Math.max(0, "kmgtp".indexOf(match[2] || "k"))) : 0;
    }

    function formatKib(kib: real): string {
        return kib >= 1024 * 1024 ? (kib / 1024 / 1024).toFixed(1) + " GB" : Math.round(kib / 1024) + " MB";
    }

    // The second frame is the one measured over the delay
    function parse(text: string) {
        const lines = text.split("\n");
        let header = -1;
        lines.forEach((line, i) => {
            if (/^\s*PID\s+USER/.test(line))
                header = i;
        });
        if (header === -1)
            return;
        const rows = [];
        for (const line of lines.slice(header + 1)) {
            const fields = line.trim().split(/\s+/);
            if (fields.length < 12)
                continue;
            const name = fields.slice(11).join(" ");
            if (name === "top")
                continue;
            rows.push({
                pid: Number(fields[0]),
                name: name,
                cpu: Number(fields[8]),
                memory: kibOf(fields[5])
            });
            if (rows.length === 5)
                break;
        }
        processes = rows;
    }

    function end(pid: int) {
        if (confirming !== pid) {
            confirming = pid;
            disarm.restart();
            return;
        }
        confirming = 0;
        Quickshell.execDetached(["kill", String(pid)]);
    }

    spacing: 4
    onActiveChanged: {
        if (active && !sampler.running)
            sampler.running = true;
        if (!active)
            confirming = 0;
    }

    Process {
        id: sampler

        command: ["top", "-b", "-n", "2", "-d", "1", "-o", "%CPU", "-e", "k", "-w", "512", "-u", Quickshell.env("USER")]
        // Dots for decimals whatever the locale
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: {
            if (root.active)
                again.restart();
        }
    }

    Timer {
        id: again

        interval: 1000
        onTriggered: sampler.running = true
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.confirming = 0
    }

    Item {
        width: parent.width
        height: title.implicitHeight

        SectionLabel {
            id: title

            text: "PROCESSES"
        }

        StyledText {
            anchors.right: parent.right
            anchors.baseline: title.baseline
            text: "by CPU"
            color: Theme.textDim
            font.pixelSize: 11
        }
    }

    StyledText {
        visible: root.processes.length === 0
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: "Measuring…"
        color: Theme.textDim
        font.pixelSize: 12
    }

    Repeater {
        model: root.processes

        Item {
            id: row

            required property var modelData
            readonly property bool essential: root.essential.includes(modelData.name)
            readonly property bool confirming: root.confirming === modelData.pid

            width: root.width
            height: 24

            StyledText {
                anchors.left: parent.left
                anchors.right: cpu.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                color: Theme.text2
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            StyledText {
                id: cpu

                anchors.right: memory.left
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                horizontalAlignment: Text.AlignRight
                text: Math.round(row.modelData.cpu) + "%"
                color: row.modelData.cpu >= 90 ? Theme.red : row.modelData.cpu >= 50 ? Theme.pink : Theme.text2
                font.pixelSize: 12
            }

            StyledText {
                id: memory

                anchors.right: endButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                horizontalAlignment: Text.AlignRight
                text: root.formatKib(row.modelData.memory)
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Rectangle {
                id: endButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: row.confirming ? endLabel.implicitWidth + 16 : 22
                height: 22
                radius: 6
                opacity: row.essential ? 0 : 1
                color: row.confirming ? Qt.alpha(Theme.red, endArea.containsMouse ? 0.55 : 0.4) : endArea.containsMouse ? Theme.hover : "transparent"

                Behavior on width {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                MaterialIcon {
                    visible: !row.confirming
                    anchors.centerIn: parent
                    text: "close"
                    size: 16
                    color: endArea.containsMouse ? Theme.red : Theme.textMuted
                }

                StyledText {
                    id: endLabel

                    visible: row.confirming
                    anchors.centerIn: parent
                    text: "End?"
                    color: Theme.text1
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: endArea

                    enabled: !row.essential
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.end(row.modelData.pid)
                }
            }
        }
    }
}
