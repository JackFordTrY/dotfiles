import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

// hyprland/window with separate-outputs: the last window title of this monitor's active
// workspace, through the module's "rewrite" rules. On an empty workspace the pill keeps its
// border but drops its background (window#waybar.empty #window).
Module {
    id: root

    required property ShellScreen screen
    property real maxTextWidth: Infinity

    readonly property var workspace: Hyprland.monitorFor(screen)?.activeWorkspace?.lastIpcObject ?? {}
    readonly property string title: rewrite(workspace.lastwindowtitle ?? "")

    // Rules in JsonCpp's sorted key order; each rule that fully matches the title is applied
    readonly property var rules: [["(.*) - Brave", "$1"], ["(.*) - Brave Search", "$1"], ["(.*) - Chromium", "$1"], ["(.*) - Outlook", "$1"], ["(.*) Microsoft Teams", "$1"]]

    function rewrite(title: string): string {
        let result = title;
        for (const [pattern, replacement] of rules) {
            if (new RegExp("^(?:" + pattern + ")$", "i").test(title))
                result = result.replace(new RegExp(pattern, "gi"), replacement);
        }
        return result;
    }

    pill: true
    radius: 12
    marginRight: 15
    padLeft: 10
    padRight: 10
    background: (workspace.windows ?? 0) === 0 ? "transparent" : Theme.moduleBg
    tooltip: title

    BarText {
        width: Math.min(textAdvance, root.maxTextWidth)
        elide: textAdvance > root.maxTextWidth ? Text.ElideRight : Text.ElideNone
        color: Theme.text2
        text: root.title
    }

    // Waybar re-reads the workspace on these events
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (["activewindow", "closewindow", "movewindow", "changefloatingmode", "fullscreen"].includes(event.name))
                Hyprland.refreshWorkspaces();
        }
    }
}
