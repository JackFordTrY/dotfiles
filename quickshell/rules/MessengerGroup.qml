import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Telegram and Discord share a tabbed group on workspace 5 (hypr/_rules.conf sends both there).
// Hyprland only adds a new window to a group that has focus as it opens, so when one opens next
// to the other it's moved into the other's group here, the group made first if there isn't one.
// Only on opening: taking one out by hand (SUPER + SHIFT + G) sticks.
Scope {
    id: root

    readonly property var messengers: /^(org\.telegram\.desktop|TelegramDesktop|telegram-desktop|discord)$/
    // Addresses waiting for their window to settle
    property var pending: []

    // Moves `address` into the group of the other messenger tiled on its workspace
    function join(address: string, clients: var) {
        const self = clients.find(c => c.address === address);
        // Gone (Discord's updater) or floating
        if (!self || self.floating)
            return;
        const other = clients.find(c => c.address !== address && !c.floating && c.workspace.id === self.workspace.id && root.messengers.test(c.class));
        if (!other || other.grouped.includes(address))
            return;
        // moveintogroup takes a direction: towards the other window, along the axis they're apart on
        const dx = other.at[0] - self.at[0];
        const dy = other.at[1] - self.at[1];
        const direction = Math.abs(dx) >= Math.abs(dy) ? (dx < 0 ? "l" : "r") : (dy < 0 ? "u" : "d");
        const makeGroup = other.grouped.length === 0 ? ["focuswindow address:" + other.address, "togglegroup"] : [];
        Focus.run([...makeGroup, "focuswindow address:" + address, "moveintogroup " + direction]);
    }

    // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "openwindow" || !root.messengers.test(event.data.split(",")[2]))
                return;
            root.pending = [...root.pending, "0x" + event.data.split(",")[0]];
            settle.restart();
        }
    }

    // Long enough for the layout to place the window
    Timer {
        id: settle

        interval: 400
        onTriggered: clients.running = true
    }

    Process {
        id: clients

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = JSON.parse(text || "[]");
                for (const address of root.pending)
                    root.join(address, list);
                root.pending = [];
            }
        }
    }
}
