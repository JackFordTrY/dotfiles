pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The active keyboard layout: its full XKB name ("English (US)") and a short form ("ENG").
Singleton {
    id: root

    property string layout
    readonly property string short: {
        const known = {
            English: "ENG",
            Russian: "RU",
            Ukrainian: "UA"
        };
        const language = layout.split(" ")[0];
        return known[language] ?? language.slice(0, 2).toUpperCase();
    }

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
        // last comma that precedes the layout's variant parenthesis
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
