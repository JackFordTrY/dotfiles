pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Active keyboard layout name as Waybar's hyprland/language shows it ("English (US)").
Singleton {
    id: root

    property string layout

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keyboards = JSON.parse(text).keyboards;
                const main = keyboards.find(k => k.main) ?? keyboards[0];
                root.layout = main?.active_keymap ?? "";
            }
        }
    }

    Connections {
        target: Hyprland

        // activelayout>>KEYBOARD,LAYOUT; both may contain commas, so take the text after the
        // last comma that precedes the layout's variant parenthesis, as Waybar does
        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "activelayout")
                return;
            const data = event.data;
            const paren = data.lastIndexOf("(");
            const before = paren < 0 ? data : data.slice(0, paren);
            root.layout = data.slice(before.lastIndexOf(",") + 1).trim();
        }
    }
}
