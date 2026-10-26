pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Docker Desktop for the system panel: whether its VM is up and the memory it holds, with a
// button to quit or start it, and each compose project or lone container with how many of it
// are running and a button to start or stop it. Stopping and quitting take a second click to
// confirm. Read every few seconds while `active` (the panel is open on the system page).
Column {
    id: root

    property bool active
    // running | starting | off, or "" before the first look
    property string status
    // The VM's resident memory, in KiB
    property real vmMemory
    // { name, project (a compose project, started and stopped as one), running, total, since },
    // the running ones first
    property var units: []
    // What's waiting for its confirming click: a unit's name, or "desktop"
    property string confirming
    // What's being started or stopped: a unit's name, or "desktop"
    property string busy

    function formatKib(kib: real): string {
        return kib >= 1024 * 1024 ? (kib / 1024 / 1024).toFixed(1) + " GB" : Math.round(kib / 1024) + " MB";
    }

    // "off", or "vm KIB" and a line per container (or "starting" while the VM boots)
    function parse(text: string) {
        const lines = text.split("\n").filter(line => line !== "");
        if (lines[0] === "off") {
            status = "off";
            units = [];
            return;
        }
        status = lines.includes("starting") ? "starting" : "running";
        vmMemory = Number((lines.find(line => line.startsWith("vm ")) ?? "vm 0").slice(3));
        const byUnit = new Map();
        for (const line of lines.filter(line => line.includes("\t"))) {
            const [name, state, project, image, since] = line.split("\t");
            const key = project || name;
            const unit = byUnit.get(key) ?? {
                name: key,
                project: project !== "",
                running: 0,
                total: 0,
                since: since
            };
            unit.total++;
            if (state === "running")
                unit.running++;
            byUnit.set(key, unit);
        }
        units = [...byUnit.values()].sort((a, b) => (b.running > 0) - (a.running > 0) || a.name.localeCompare(b.name));
    }

    // "up 45 hours", "3 weeks ago", "2 of 5 up"
    function detailOf(unit: var): string {
        if (unit.total > 1)
            return unit.running === unit.total ? "all " + unit.total + " up" : unit.running > 0 ? unit.running + " of " + unit.total + " up" : unit.total + " stopped";
        return unit.running > 0 ? unit.since.replace(/^Up /, "up ") : unit.since.replace(/^Exited \(\d+\) /, "stopped ");
    }

    function toggle(unit: var) {
        const running = unit.running > 0;
        if (running && confirming !== unit.name) {
            confirming = unit.name;
            disarm.restart();
            return;
        }
        confirming = "";
        const verb = running ? "stop" : "start";
        run(unit.name, unit.project ? ["docker", "compose", "-p", unit.name, verb] : ["docker", verb, unit.name]);
    }

    function toggleDesktop() {
        if (status === "off") {
            run("desktop", ["systemctl", "--user", "start", "docker-desktop"]);
            return;
        }
        if (confirming !== "desktop") {
            confirming = "desktop";
            disarm.restart();
            return;
        }
        confirming = "";
        run("desktop", ["systemctl", "--user", "stop", "docker-desktop"]);
    }

    function run(what: string, command: var) {
        if (action.running)
            return;
        busy = what;
        action.command = command;
        action.running = true;
    }

    spacing: 4
    onActiveChanged: {
        if (active && !reader.running)
            reader.running = true;
        if (!active)
            confirming = "";
    }

    Process {
        id: reader

        command: ["sh", "-c", "systemctl --user is-active -q docker-desktop || { echo off; exit; }; " + "echo \"vm $(ps -o rss= -C qemu-system-x86_64 | awk '{ s += $1 } END { print s + 0 }')\"; " + "docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Label \"com.docker.compose.project\"}}\t{{.Image}}\t{{.Status}}' 2>/dev/null || echo starting"]
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

        interval: 3000
        onTriggered: reader.running = true
    }

    Process {
        id: action

        onExited: {
            root.busy = "";
            if (!reader.running)
                reader.running = true;
        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.confirming = ""
    }

    Item {
        width: parent.width
        height: title.implicitHeight

        SectionLabel {
            id: title

            text: "DOCKER"
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            spacing: 12

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.status === "running" ? "VM " + root.formatKib(root.vmMemory) : root.status === "starting" ? "Starting…" : ""
                color: Theme.textDim
                font.pixelSize: 11
            }

            // Quit or start Docker Desktop
            Item {
                visible: root.status !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: desktopRow.implicitWidth
                height: desktopRow.implicitHeight

                Row {
                    id: desktopRow

                    readonly property bool confirming: root.confirming === "desktop"
                    readonly property color tint: confirming ? Theme.red : desktopArea.containsMouse ? Theme.text1 : Theme.textMuted

                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.status === "off" ? "play_arrow" : "power_settings_new"
                        size: 16
                        color: desktopRow.tint
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.busy === "desktop" ? (root.status === "off" ? "Starting…" : "Quitting…") : root.status === "off" ? "Start" : desktopRow.confirming ? "Quit?" : "Quit"
                        color: desktopRow.tint
                        font.pixelSize: 11
                        font.bold: desktopRow.confirming
                    }
                }

                MouseArea {
                    id: desktopArea

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDesktop()
                }
            }
        }
    }

    StyledText {
        visible: root.status !== "running" || root.units.length === 0
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: root.status === "off" ? "Docker Desktop is off" : root.status === "starting" ? "Waiting for the VM…" : root.status === "running" ? "No containers" : "Looking…"
        color: Theme.textDim
        font.pixelSize: 12
    }

    Repeater {
        model: root.status === "running" ? root.units : []

        Item {
            id: row

            required property var modelData
            readonly property bool running: modelData.running > 0
            readonly property bool confirming: root.confirming === modelData.name
            readonly property bool busy: root.busy === modelData.name

            width: root.width
            height: 24

            Rectangle {
                id: dot

                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: row.modelData.running === 0 ? Theme.textDim : row.modelData.running === row.modelData.total ? Theme.green : Theme.yellow
            }

            StyledText {
                anchors.left: dot.right
                anchors.leftMargin: 10
                anchors.right: detail.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                color: row.running ? Theme.text2 : Theme.textMuted
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            StyledText {
                id: detail

                anchors.right: button.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.detailOf(row.modelData)
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Rectangle {
                id: button

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: row.confirming ? confirmLabel.implicitWidth + 16 : 22
                height: 22
                radius: 6
                color: row.confirming ? Qt.alpha(Theme.red, buttonArea.containsMouse ? 0.55 : 0.4) : buttonArea.containsMouse ? Theme.hover : "transparent"

                Behavior on width {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                MaterialIcon {
                    visible: !row.confirming
                    anchors.centerIn: parent
                    text: row.busy ? "progress_activity" : row.running ? "stop" : "play_arrow"
                    size: 16
                    color: row.busy ? Theme.accent : buttonArea.containsMouse ? (row.running ? Theme.red : Theme.green) : Theme.textMuted

                    RotationAnimation on rotation {
                        running: row.busy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }

                StyledText {
                    id: confirmLabel

                    visible: row.confirming
                    anchors.centerIn: parent
                    text: "Stop?"
                    color: Theme.text1
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: buttonArea

                    enabled: !row.busy
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(row.modelData)
                }
            }
        }
    }
}
