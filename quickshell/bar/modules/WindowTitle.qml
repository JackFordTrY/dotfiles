import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components

// The app last focused on this monitor's active workspace, by a short name ("Code", "Opera");
// the full window title is in the tooltip. Hidden on an empty workspace.
TabItem {
    id: root

    required property ShellScreen screen

    readonly property HyprlandWorkspace workspace: Hyprland.monitorFor(screen)?.activeWorkspace ?? null
    readonly property HyprlandToplevel toplevel: {
        const active = Hyprland.activeToplevel;
        if (active && active.workspace === workspace)
            return active;
        const address = workspace?.lastIpcObject?.lastwindow ?? "";
        return workspace?.toplevels.values.find(t => "0x" + t.address === address) ?? null;
    }
    readonly property string appId: toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || ""
    readonly property string name: shortName(appId)

    // Names that the desktop entry spells out too long, keyed by lowercase app id
    readonly property var names: ({
            "com.microsoft.vscode": "Code",
            "code-oss": "Code",
            "org.telegram.desktop": "Telegram",
            "org.gnome.nautilus": "Files",
            "org.pulseaudio.pavucontrol": "Volume",
            "pavucontrol": "Volume",
            "blueman-manager": "Bluetooth",
            "google-chrome": "Chrome",
            "brave-browser": "Brave"
        })

    function shortName(appId: string): string {
        if (appId === "")
            return "";
        const known = names[appId.toLowerCase()];
        if (known)
            return known;
        const entry = DesktopEntries.heuristicLookup(appId);
        const name = (entry?.name || appId.split(".").pop()).replace(/[-_]/g, " ").split(" ").slice(0, 2).join(" ");
        return name.charAt(0).toUpperCase() + name.slice(1, 20);
    }

    text: name
    padding: 8
    tooltip: toplevel?.title ?? ""
    visible: name !== ""

    // Keeps the workspace's lastwindow current for monitors that don't have focus
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (["activewindow", "closewindow", "movewindow"].includes(event.name))
                Hyprland.refreshWorkspaces();
        }
    }
}
