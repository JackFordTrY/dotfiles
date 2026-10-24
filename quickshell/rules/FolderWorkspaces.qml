import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// VS Code windows go to the workspace for their folder, once their title names it. Hyprland's
// own rules only see a new window's first title, which is just "Visual Studio Code"; the folder
// shows up a moment later ("main.ts - work_lgfg - Visual Studio Code"). Each window is placed
// once, so moving it by hand afterwards sticks.
Scope {
    id: root

    // Folder name, as VS Code's title shows it, to workspace
    readonly property var folders: ({
            "work": 3,
            "work_lgfg": 4
        })
    // Addresses already placed
    property var placed: ({})

    // The workspace a VS Code title belongs on, or 0
    function workspaceFor(title: string): int {
        const suffix = " - Visual Studio Code";
        if (!title.endsWith(suffix))
            return 0;
        // "editor - folder - [profile - ]Visual Studio Code"
        const parts = title.slice(0, -suffix.length).split(" - ");
        const folder = Object.keys(folders).find(f => parts.slice(1).includes(f) || (parts.length === 1 && parts[0] === f));
        return folder === undefined ? 0 : folders[folder];
    }

    // windowtitlev2>>ADDRESS,TITLE
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "windowtitlev2")
                return;
            const comma = event.data.indexOf(",");
            const address = event.data.slice(0, comma);
            const workspace = root.workspaceFor(event.data.slice(comma + 1));
            if (workspace === 0 || root.placed[address])
                return;
            root.placed[address] = true;
            // Follow the window if it's the one being worked in
            const follow = Hyprland.activeToplevel?.address === address;
            Focus.run([(follow ? "movetoworkspace " : "movetoworkspacesilent ") + workspace + ",address:0x" + address]);
        }
    }
}
