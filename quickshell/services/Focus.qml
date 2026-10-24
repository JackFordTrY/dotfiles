pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Focus changes the shell makes (following a song or a notification, placing Resources, moving
// VS Code windows) without the cursor jumping: Hyprland warps it to every newly focused window
// unless cursor:no_warps is on, so it's switched on for just these dispatches, in one batch, and
// put back to what it was.
Singleton {
    id: root

    // cursor:no_warps as configured
    property bool noWarps: false

    // Hyprland dispatches, without the "dispatch" word: "focuswindow address:0x..."
    function run(dispatches: var) {
        Quickshell.execDetached(["hyprctl", "--batch", ["keyword cursor:no_warps 1", ...dispatches.map(d => "dispatch " + d), "keyword cursor:no_warps " + (noWarps ? 1 : 0)].join(" ; ")]);
    }

    Process {
        running: true
        command: ["hyprctl", "getoption", "cursor:no_warps", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.noWarps = (JSON.parse(text || "{}").int ?? 0) !== 0
        }
    }
}
