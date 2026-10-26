pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// SUPER + Tab (`qs ipc call overview toggle`): every workspace over the wallpaper, with live
// previews of its windows where they sit on the screen. Click a window to switch to it, an empty
// spot to go to that workspace, or drag a window onto another workspace to move it there; the
// cross on a hovered window (or a middle click) closes it. The arrows (or Tab) step through the
// windows, Enter switches to the selected one and Delete closes it; typing dims the windows
// whose title or app doesn't hold it and selects the first that does.
Overlay {
    id: root

    // Shown even while empty, with the bar's icons (see Workspaces)
    readonly property var kinds: ({
            1: "home",
            2: "public",
            3: "code",
            4: "terminal",
            5: "handyman"
        })
    readonly property int perRow: 5
    readonly property var monitor: Hyprland.focusedMonitor
    // The monitor in layout coordinates, which window positions are in
    readonly property rect screenArea: Qt.rect(monitor?.x ?? 0, monitor?.y ?? 0, (monitor?.width ?? 2560) / (monitor?.scale ?? 1), (monitor?.height ?? 1600) / (monitor?.scale ?? 1))
    readonly property var workspaceIds: {
        const ids = new Set(Object.keys(kinds).map(Number));
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.id > 0)
                ids.add(workspace.id);
        }
        return [...ids].sort((a, b) => a - b);
    }
    readonly property int across: Math.min(perRow, workspaceIds.length)
    readonly property real tileWidth: (panelWidth - 28 - 14 * (across - 1)) / across
    // Hyprpaper's wallpaper per monitor name ("" for the rest), from hypr/hyprpaper.conf
    property var wallpapers: ({})
    readonly property string wallpaper: wallpapers[monitor?.name ?? ""] ?? wallpapers[""] ?? ""

    // Every window off the special workspaces, by workspace and then left to right
    readonly property var windows: Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) > 0).sort((a, b) => a.workspace.id - b.workspace.id || (a.lastIpcObject.at?.[0] ?? 0) - (b.lastIpcObject.at?.[0] ?? 0))
    readonly property var matching: windows.filter(t => matches(t))
    property var selected: null

    function matches(toplevel: var): bool {
        const q = query.trim().toLowerCase();
        return q === "" || toplevel.title.toLowerCase().includes(q) || (toplevel.wayland?.appId ?? "").toLowerCase().includes(q);
    }

    function step(by: int) {
        if (matching.length === 0)
            return;
        const at = matching.indexOf(selected);
        selected = matching[at === -1 ? 0 : (at + by + matching.length) % matching.length];
    }

    function focusWindow(toplevel: var) {
        close();
        Focus.run(["focuswindow address:0x" + toplevel.address]);
    }

    function goTo(id: int) {
        close();
        Hyprland.dispatch("workspace " + id);
    }

    function closeWindow(toplevel: var) {
        Hyprland.dispatch("closewindow address:0x" + toplevel.address);
    }

    function moveTo(toplevel: var, id: int) {
        if (toplevel.workspace?.id !== id)
            Hyprland.dispatch("movetoworkspacesilent " + id + ",address:0x" + toplevel.address);
    }

    function iconOf(toplevel: var): string {
        const icon = DesktopEntries.heuristicLookup(toplevel?.wayland?.appId ?? "")?.icon ?? "";
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable");
    }

    WlrLayershell.namespace: "quickshell-overview"
    panelWidth: Math.min(1800, (screen?.width ?? 2048) * 0.9)
    placeholder: "Search windows"
    onOpened: {
        // Positions and workspaces as they are now
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        selected = windows.includes(Hyprland.activeToplevel) ? Hyprland.activeToplevel : windows[0] ?? null;
    }
    // Hyprland counts the live previews as a screencast; the recording indicator leaves it out
    onOpenChanged: Privacy.selfCapturing = open
    onQueryChanged: {
        if (!matching.includes(selected))
            selected = matching[0] ?? null;
    }
    // The selected window closed
    onMatchingChanged: {
        if (selected && !matching.includes(selected))
            selected = matching[0] ?? null;
    }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            step(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            step(1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (selected)
                focusWindow(selected);
            break;
        case Qt.Key_Delete:
            if (selected)
                closeWindow(selected);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggle();
        }
    }

    // wallpaper { monitor = eDP-1  path = ... }
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/hyprpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const wallpapers = {};
            const conf = text();
            const blocks = /wallpaper\s*\{([^}]*)\}/g;
            for (let block = blocks.exec(conf); block !== null; block = blocks.exec(conf)) {
                const monitor = block[1].match(/^\s*monitor\s*=\s*(.*?)\s*$/m)?.[1] ?? "";
                const path = block[1].match(/^\s*path\s*=\s*(.*?)\s*$/m)?.[1];
                if (path)
                    wallpapers[monitor] = path;
            }
            root.wallpapers = wallpapers;
        }
    }

    Grid {
        width: parent.width
        columns: root.across
        spacing: 14

        Repeater {
            model: root.workspaceIds

            WorkspaceTile {}
        }
    }

    // What follows the pointer while a window is dragged to another workspace
    above: Rectangle {
        id: ghost

        property var toplevel: null
        property bool dragging: false

        visible: dragging
        width: Math.min(260, ghostRow.implicitWidth + 24)
        height: 40
        radius: 12
        color: Theme.active
        border.width: 1
        border.color: Theme.accent
        Drag.active: dragging
        Drag.keys: ["window"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Row {
            id: ghostRow

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                sourceSize.width: 20
                sourceSize.height: 20
                source: ghost.toplevel ? root.iconOf(ghost.toplevel) : ""
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                text: ghost.toplevel?.title ?? ""
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    component WorkspaceTile: Column {
        id: tile

        required property int modelData
        readonly property bool current: root.monitor?.activeWorkspace?.id === modelData
        readonly property var windows: root.windows.filter(t => t.workspace?.id === modelData)

        width: root.tileWidth
        spacing: 6

        Row {
            spacing: 6

            MaterialIcon {
                visible: root.kinds[tile.modelData] !== undefined
                anchors.verticalCenter: parent.verticalCenter
                text: root.kinds[tile.modelData] ?? ""
                size: 16
                color: tile.current ? Theme.accent : Theme.textMuted
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: tile.modelData
                color: tile.current ? Theme.text1 : Theme.textMuted
                font.pixelSize: 12
                font.bold: true
            }
        }

        // The screen, scaled down
        Rectangle {
            id: display

            readonly property real factor: width / root.screenArea.width

            width: parent.width
            height: width * root.screenArea.height / root.screenArea.width
            radius: 10
            color: Theme.surface1
            border.width: tile.current || drop.containsDrag ? 2 : 1
            border.color: drop.containsDrag ? Theme.accent : tile.current ? Theme.purpleGlowStrong : Theme.purpleGlow
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: root.wallpaper === "" ? "" : "file://" + root.wallpaper
                sourceSize.width: width * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.6
            }

            // An empty spot goes to the workspace
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goTo(tile.modelData)
            }

            DropArea {
                id: drop

                anchors.fill: parent
                keys: ["window"]
                onDropped: event => root.moveTo(event.source.toplevel, tile.modelData)
            }

            Repeater {
                model: tile.windows

                WindowThumb {
                    factor: display.factor
                }
            }
        }
    }

    component WindowThumb: Rectangle {
        id: thumb

        required property var modelData
        property real factor
        readonly property var ipc: modelData.lastIpcObject
        readonly property bool selected: root.selected === modelData
        readonly property bool lit: selected || hover.hovered

        x: ((ipc.at?.[0] ?? 0) - root.screenArea.x) * factor
        y: ((ipc.at?.[1] ?? 0) - root.screenArea.y) * factor
        width: Math.max(24, (ipc.size?.[0] ?? 0) * factor)
        height: Math.max(18, (ipc.size?.[1] ?? 0) * factor)
        // Floating windows over the tiled ones
        z: ipc.floating ? 1 : 0
        radius: 6
        color: Theme.surface3
        border.width: lit ? 2 : 1
        border.color: lit ? Theme.accent : Theme.purpleGlow
        opacity: root.matches(modelData) ? 1 : 0.3

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        ScreencopyView {
            id: capture

            anchors.fill: parent
            anchors.margins: thumb.border.width
            captureSource: thumb.modelData.wayland
            live: root.open
            constraintSize: Qt.size(thumb.width * 2, thumb.height * 2)
        }

        // The app's icon, in the middle until the preview arrives and then in a corner
        Image {
            readonly property real size: capture.hasContent ? 20 : Math.min(36, thumb.height * 0.5)

            x: capture.hasContent ? thumb.width - width - 6 : (thumb.width - width) / 2
            y: capture.hasContent ? thumb.height - height - 6 : (thumb.height - height) / 2
            width: size
            height: size
            sourceSize.width: 36
            sourceSize.height: 36
            source: root.iconOf(thumb.modelData)
        }

        Rectangle {
            visible: thumb.lit && thumb.height > 40
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: thumb.border.width
            height: 22
            color: Theme.popupBackground

            StyledText {
                x: 6
                width: parent.width - 12 - (closeButton.visible ? closeButton.width + 4 : 0)
                anchors.verticalCenter: parent.verticalCenter
                text: thumb.modelData.title
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Doesn't take the hover from the button over it
        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.closeWindow(thumb.modelData);
                else
                    root.focusWindow(thumb.modelData);
            }
        }

        Rectangle {
            id: closeButton

            visible: hover.hovered && thumb.width > 60
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 3
            width: 18
            height: 18
            radius: 5
            color: Qt.alpha(Theme.red, closeArea.containsMouse ? 0.85 : 0.55)

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                size: 14
                color: Theme.text1
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeWindow(thumb.modelData)
            }
        }

        // Takes over from the click once the pointer has moved
        DragHandler {
            target: null
            onActiveChanged: {
                if (active) {
                    ghost.toplevel = thumb.modelData;
                    ghost.dragging = true;
                } else {
                    ghost.Drag.drop();
                    ghost.dragging = false;
                    ghost.toplevel = null;
                }
            }
            onCentroidChanged: {
                if (!active)
                    return;
                const at = ghost.parent.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                ghost.x = at.x - ghost.width / 2;
                ghost.y = at.y - ghost.height / 2;
            }
        }
    }
}
