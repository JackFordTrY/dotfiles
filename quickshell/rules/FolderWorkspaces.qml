import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// VS Code windows go to the workspace for their folder, once their title names it. Hyprland's
// own rules only see a new window's first title, which is just "Visual Studio Code"; the folder
// shows up a moment later ("main.ts - work_lgfg - Visual Studio Code"). Dialogs (Revert,
// Save changes?) keep that first title, so they stay over the window they belong to. Each
// window is placed once, so moving it by hand afterwards sticks.
Scope {
    id: root

    // Folder name, as VS Code's title shows it, to workspace
    readonly property var folders: ({
            "work": 3,
            "work_lgfg": 4
        })
    // Where windows of any other folder go
    readonly property int otherFolders: 3
    // VS Code window addresses, from their class when they open
    property var vscode: ({})
    // Addresses already placed
    property var placed: ({})

    // The workspace a pinned folder opens on, or 0
    function workspaceOf(folder: string): int {
        return folders[folder] ?? 0;
    }

    // The workspace a VS Code title belongs on, or 0 while it's still a bare "Visual Studio Code"
    function workspaceFor(title: string): int {
        const suffix = " - Visual Studio Code";
        if (!title.endsWith(suffix))
            return 0;
        // "editor - folder - [profile - ]Visual Studio Code"
        const parts = title.slice(0, -suffix.length).split(" - ");
        const folder = Object.keys(folders).find(f => parts.slice(1).includes(f) || (parts.length === 1 && parts[0] === f));
        return folder === undefined ? otherFolders : folders[folder];
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            const comma = event.data.indexOf(",");
            const address = event.data.slice(0, comma);
            // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
            if (event.name === "openwindow") {
                if (/^(code|com\.microsoft\.VSCode)$/.test(event.data.split(",")[2]))
                    root.vscode[address] = true;
                return;
            }
            if (event.name === "closewindow") {
                delete root.vscode[address];
                delete root.placed[address];
                return;
            }
            // windowtitlev2>>ADDRESS,TITLE
            if (event.name !== "windowtitlev2" || !root.vscode[address] || root.placed[address])
                return;
            const workspace = root.workspaceFor(event.data.slice(comma + 1));
            if (workspace === 0)
                return;
            root.placed[address] = true;
            // Follow the window if it's the one being worked in. Tiled, as it may have opened
            // on workspace 1, where everything floats
            const follow = Hyprland.activeToplevel?.address === address;
            const target = "address:0x" + address;
            Focus.run([(follow ? "movetoworkspace " : "movetoworkspacesilent ") + workspace + "," + target, "settiled " + target]);
        }
    }
}
