pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Active port and form factor of the default sink, which Waybar's pulseaudio module uses to
// pick the headphone/headset/... icon. Pipewire nodes don't expose the port, so ask pactl.
Singleton {
    id: root

    property string portName
    property string formFactor

    Process {
        id: query

        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sink = JSON.parse(text).find(s => s.name === Pipewire.defaultAudioSink?.name);
                root.portName = sink?.active_port ?? "";
                root.formFactor = sink?.properties?.["device.form_factor"] ?? "";
            }
        }
    }

    Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (/ on (sink|card|server)/.test(line))
                    debounce.restart();
            }
        }
    }

    Timer {
        id: debounce

        interval: 100
        onTriggered: query.running = true
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            debounce.restart();
        }
    }

    Component.onCompleted: query.running = true
}
