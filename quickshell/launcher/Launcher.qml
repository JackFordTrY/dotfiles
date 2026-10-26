pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The app launcher (SUPER + R runs `qs ipc call launcher toggle`): a row of pinned apps and every
// app, most launched first, under the search field. Left and Right cycle round the pinned apps
// (the row scrolls when they don't fit), Up and Down go through the list, typing searches it and
// Enter launches the selection. Open windows matching the query come first, and Enter switches
// to them instead of starting another; arithmetic ("2*21") shows its result on top, which Enter
// copies; when nothing matches, Enter searches the web; "> command" runs the command in a new
// kitty window. A right click or Shift+Enter on an app lists its own actions ("New Private
// Window"). Escape, SUPER + R again or a click outside the panel closes it.
Overlay {
    id: root

    // Desktop entry ids; `folder` (under ~) opens VS Code on it, named by `label` under the icon
    readonly property var pinned: [
        {
            id: "opera"
        },
        {
            id: "org.telegram.desktop"
        },
        {
            id: "discord"
        },
        {
            id: "com.microsoft.VSCode",
            label: "work",
            folder: "work"
        },
        {
            id: "com.microsoft.VSCode",
            label: "work_lgfg",
            folder: "work_lgfg"
        }
    ]
    // Pinned tiles across the panel; more scroll
    readonly property int pinnedShown: 5
    // List rows shown at once
    readonly property int shownRows: 8
    // Matching windows listed at most
    readonly property int shownWindows: 4

    // Where pinned folders open (rules/FolderWorkspaces.qml)
    property var folderWorkspaces
    // Where the arrows and Enter act: "pinned" or "list"
    property string area: "pinned"
    property int pinnedIndex: 0
    property int listIndex: 0
    // Launch counts rofi kept (~/.cache/rofi3.druncache, left behind when it was removed), so the
    // order it learned carries over; the launcher's own counts add to them
    property var rofiUses: ({})
    // The app whose actions menu is up, and the action picked in it
    property var actionsEntry: null
    property int actionIndex: 0

    readonly property var pinnedApps: {
        // Looked up again when the entries change
        DesktopEntries.applications.values;
        return pinned.map(p => ({
                    entry: DesktopEntries.byId(p.id),
                    label: p.label ?? "",
                    folder: p.folder ?? ""
                })).filter(p => p.entry);
    }

    // The apps matching the query, best first, then most launched
    readonly property var results: {
        const q = query.trim().toLowerCase();
        const found = [];
        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay)
                continue;
            const match = q === "" ? {
                tier: 0,
                at: []
            } : matchOf(entry, q);
            if (match)
                found.push({
                    kind: "app",
                    entry: entry,
                    tier: match.tier,
                    at: match.at,
                    uses: usesOf(entry.id)
                });
        }
        found.sort((a, b) => b.tier - a.tier || b.uses - a.uses || a.entry.name.localeCompare(b.entry.name));
        return found;
    }

    // Open windows whose title or app holds the query
    readonly property var windows: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        return Hyprland.toplevels.values.filter(t => t.title.toLowerCase().includes(q) || (t.wayland?.appId ?? "").toLowerCase().includes(q)).slice(0, shownWindows).map(t => {
            const at = t.title.toLowerCase().indexOf(q);
            return {
                kind: "window",
                toplevel: t,
                at: at === -1 ? [] : Array.from({
                    length: q.length
                }, (_, i) => at + i)
            };
        });
    }

    // What the list shows: the result first when the query is arithmetic, then the windows and
    // apps, then a web search when nothing matches
    readonly property var rows: {
        const q = query.trim();
        if (q.startsWith(">"))
            return [
                {
                    kind: "command",
                    command: q.slice(1).trim()
                }
            ];
        const answer = calculate(q);
        return [...(answer === null ? [] : [
                    {
                        kind: "calc",
                        value: answer
                    }
                ]), ...windows, ...results, ...(q !== "" && results.length === 0 && windows.length === 0 ? [
                    {
                        kind: "web"
                    }
                ] : [])];
    }

    // The value of `q` when it's arithmetic ("2*21", "(3 + 4)^2 / 7"), as text, else null. Only
    // digits, operators and brackets get as far as being evaluated
    function calculate(q: string): var {
        if (!/^[\d\s.+\-*\/%^()]+$/.test(q) || !/\d/.test(q) || !/[+\-*\/%^]/.test(q.replace(/^\s*-/, "")))
            return null;
        try {
            const value = Function(`"use strict"; return (${q.replace(/\^/g, "**")});`)();
            return typeof value === "number" && isFinite(value) ? String(Number(value.toPrecision(12))) : null;
        } catch (e) {
            return null;
        }
    }

    function usesOf(id: string): int {
        return (rofiUses[id] ?? 0) + (counts.uses[id] ?? 0);
    }

    // How well `q` matches an app and which characters of its name it covers: a run at the start
    // of the name, at a word start, anywhere in it, or its characters in order; failing those, the
    // description, id or keywords containing it. Null if nothing matches
    function matchOf(entry: var, q: string): var {
        const name = entry.name.toLowerCase();
        const run = start => Array.from({
                length: q.length
            }, (_, i) => start + i);
        if (name.startsWith(q))
            return {
                tier: 5,
                at: run(0)
            };
        for (let i = name.indexOf(q); i !== -1; i = name.indexOf(q, i + 1)) {
            if (" -_.".includes(name[i - 1]))
                return {
                    tier: 4,
                    at: run(i)
                };
        }
        if (name.includes(q))
            return {
                tier: 3,
                at: run(name.indexOf(q))
            };
        const inOrder = charactersOf(name, q);
        if (inOrder)
            return {
                tier: 2,
                at: inOrder
            };
        if ([entry.genericName, entry.id, ...entry.keywords].some(t => t.toLowerCase().includes(q)))
            return {
                tier: 1,
                at: []
            };
        return null;
    }

    // Where each character of `q` (spaces aside) falls in `text`, in order, or null
    function charactersOf(text: string, q: string): var {
        const at = [];
        for (const c of q.replace(/\s/g, "")) {
            const i = text.indexOf(c, at.length > 0 ? at[at.length - 1] + 1 : 0);
            if (i === -1)
                return null;
            at.push(i);
        }
        return at;
    }

    function escaped(text: string): string {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // The name with the matched characters in bold accent
    function marked(text: string, at: var): string {
        let out = "";
        for (let i = 0; i < text.length; i++)
            out += at.includes(i) ? `<b><font color="${Theme.accent}">${escaped(text[i])}</font></b>` : escaped(text[i]);
        return out;
    }

    // "Workspace 3", or a special workspace's name ("Kitty")
    function workspaceLabel(workspace: var): string {
        const name = workspace?.name ?? "";
        if (!name.startsWith("special:"))
            return "Workspace " + name;
        const special = name.slice("special:".length);
        return special.charAt(0).toUpperCase() + special.slice(1);
    }

    // Into the pinned row on the first press, then round it, wrapping at the ends
    function stepPinned(step: int) {
        const count = pinnedApps.length;
        if (count === 0)
            return;
        if (area === "pinned")
            pinnedIndex = (pinnedIndex + step + count) % count;
        area = "pinned";
        pinnedView.positionViewAtIndex(pinnedIndex, ListView.Contain);
    }

    // Down from the pinned row enters the list; Up from the top of the list goes back to it
    function stepList(step: int) {
        if (area === "pinned") {
            if (step > 0 && rows.length > 0)
                area = "list";
            return;
        }
        if (step < 0 && listIndex === 0) {
            if (pinnedApps.length > 0)
                area = "pinned";
            return;
        }
        listIndex = Math.max(0, Math.min(rows.length - 1, listIndex + step));
        list.positionViewAtIndex(listIndex, ListView.Contain);
    }

    function activate() {
        if (area === "pinned") {
            const pin = pinnedApps[pinnedIndex];
            if (pin)
                launch(pin.entry, pin.folder);
        } else if (rows[listIndex]) {
            pick(rows[listIndex]);
        }
    }

    function pick(row: var) {
        if (row.kind === "app") {
            launch(row.entry, "");
            return;
        }
        if (row.kind === "command" && row.command === "")
            return;
        close();
        // Its own class, so the kitty rule doesn't send it to the scratchpad; held open to read
        if (row.kind === "command")
            Quickshell.execDetached(["kitty", "--class", "launcher-command", "--hold", "sh", "-c", row.command]);
        else if (row.kind === "window")
            Focus.run(["focuswindow address:0x" + row.toplevel.address]);
        else if (row.kind === "calc")
            Quickshell.execDetached(["wl-copy", row.value]);
        else
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(query.trim())]);
    }

    function counted(entry: var) {
        const uses = Object.assign({}, counts.uses);
        uses[entry.id] = (uses[entry.id] ?? 0) + 1;
        counts.uses = uses;
        store.writeAdapter();
    }

    function launch(entry: var, folder: string) {
        close();
        counted(entry);
        if (folder === "") {
            entry.execute();
            return;
        }
        // Onto the folder's workspace first, so the window opens there rather than moving later
        const workspace = folderWorkspaces?.workspaceOf(folder) ?? 0;
        if (workspace !== 0)
            Hyprland.dispatch("workspace " + workspace);
        // `command` comes without the Exec line's field codes (%F)
        Quickshell.execDetached([...entry.command, Quickshell.env("HOME") + "/" + folder]);
    }

    // Opens the actions menu of `entry` under `item` (above it near the panel's bottom)
    function showActions(entry: var, item: var) {
        if (!entry || entry.actions.length === 0)
            return;
        actionsEntry = entry;
        actionIndex = 0;
        const below = item.mapToItem(actionsMenu.parent, 0, item.height + 4);
        actionsMenu.x = Math.min(below.x + 10, actionsMenu.parent.width - actionsMenu.width - 14);
        actionsMenu.y = below.y + actionsMenu.height > actionsMenu.parent.height - 14 ? below.y - item.height - 8 - actionsMenu.height : below.y;
    }

    // The selection's actions, from Shift+Enter
    function showSelectedActions() {
        if (area === "pinned")
            showActions(pinnedApps[pinnedIndex]?.entry, pinnedView.currentItem);
        else if (rows[listIndex]?.kind === "app")
            showActions(rows[listIndex].entry, list.currentItem);
    }

    function runAction(index: int) {
        const entry = actionsEntry;
        actionsEntry = null;
        close();
        counted(entry);
        entry.actions[index].execute();
    }

    WlrLayershell.namespace: "quickshell-launcher"
    onOpened: {
        area = "pinned";
        pinnedIndex = 0;
        listIndex = 0;
        actionsEntry = null;
        pinnedView.positionViewAtBeginning();
        list.positionViewAtBeginning();
        // Titles and workspaces as they are now
        Hyprland.refreshToplevels();
    }
    onQueryChanged: {
        area = query.trim() === "" ? "pinned" : "list";
        listIndex = 0;
        actionsEntry = null;
        list.positionViewAtBeginning();
    }
    onKeyPressed: event => {
        // The actions menu takes the arrows, Enter and Escape while it's up
        if (actionsEntry) {
            const count = actionsEntry.actions.length;
            switch (event.key) {
            case Qt.Key_Up:
                actionIndex = (actionIndex + count - 1) % count;
                break;
            case Qt.Key_Down:
                actionIndex = (actionIndex + 1) % count;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                runAction(actionIndex);
                break;
            case Qt.Key_Escape:
            case Qt.Key_Left:
            case Qt.Key_Right:
                actionsEntry = null;
                break;
            default:
                return;
            }
            event.accepted = true;
            return;
        }
        switch (event.key) {
        case Qt.Key_Left:
            stepPinned(-1);
            break;
        case Qt.Key_Right:
            stepPinned(1);
            break;
        case Qt.Key_Up:
            stepList(-1);
            break;
        case Qt.Key_Down:
            stepList(1);
            break;
        case Qt.Key_PageUp:
            stepList(-shownRows);
            break;
        case Qt.Key_PageDown:
            stepList(shownRows);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.modifiers & Qt.ShiftModifier)
                showSelectedActions();
            else
                activate();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/rofi3.druncache"
        // "202 opera.desktop"
        onLoaded: {
            const uses = {};
            for (const line of text().split("\n")) {
                const match = line.match(/^(\d+) (.+)\.desktop$/);
                if (match)
                    uses[match[2]] = Number(match[1]);
            }
            root.rofiUses = uses;
        }
    }

    FileView {
        id: store

        path: Quickshell.statePath("launcher.json")

        JsonAdapter {
            id: counts

            property var uses: ({})
        }
    }

    ListView {
        id: pinnedView

        readonly property int across: Math.max(1, Math.min(count, root.pinnedShown))
        readonly property real tileWidth: (width - spacing * (across - 1)) / across

        visible: count > 0
        width: parent.width
        height: 84
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.pinnedApps
        currentIndex: root.pinnedIndex
        delegate: PinnedTile {}
    }

    Rectangle {
        visible: pinnedView.visible
        width: parent.width
        height: 1
        color: Theme.purpleGlow
    }

    ListView {
        id: list

        width: parent.width
        height: root.shownRows * 40 + (root.shownRows - 1) * spacing
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows
        currentIndex: root.listIndex
        delegate: AppRow {}

        StyledText {
            visible: list.count === 0
            anchors.centerIn: parent
            text: "No matches"
            color: Theme.textDim
        }
    }

    above: [
        // A click elsewhere in the panel closes the actions menu
        MouseArea {
            visible: root.actionsEntry !== null
            anchors.fill: parent
            onPressed: root.actionsEntry = null
        },
        Rectangle {
            id: actionsMenu

            visible: root.actionsEntry !== null
            width: 260
            height: actions.implicitHeight + 12
            radius: 12
            color: Theme.popupBackground
            border.width: 1
            border.color: Theme.purpleGlowStrong

            Column {
                id: actions

                x: 6
                y: 6
                width: parent.width - 12

                Repeater {
                    model: root.actionsEntry?.actions ?? []

                    Rectangle {
                        id: action

                        required property var modelData
                        required property int index

                        width: actions.width
                        height: 34
                        radius: 8
                        color: index === root.actionIndex ? Theme.active : actionArea.containsMouse ? Theme.hover : "transparent"

                        AppIcon {
                            id: actionIcon

                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            entry: action.modelData.icon !== "" ? action.modelData : root.actionsEntry
                            size: 20
                        }

                        StyledText {
                            anchors.left: actionIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: action.modelData.name
                            color: action.index === root.actionIndex ? Theme.text1 : Theme.text2
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runAction(action.index)
                        }
                    }
                }
            }
        }
    ]

    component AppIcon: Image {
        property var entry
        property real size: 24

        width: size
        height: size
        sourceSize.width: size
        sourceSize.height: size
        asynchronous: true
        source: {
            const icon = entry?.icon ?? "";
            return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable");
        }
    }

    component PinnedTile: Rectangle {
        id: tile

        required property var modelData
        required property int index
        readonly property bool selected: root.area === "pinned" && index === root.pinnedIndex

        width: pinnedView.tileWidth
        height: pinnedView.height
        radius: 12
        color: selected ? Theme.active : tileArea.containsMouse ? Theme.hover : Theme.raised
        border.width: 1
        border.color: selected || tileArea.containsMouse ? Theme.purpleGlowStrong : Theme.purpleGlow

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            AppIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                entry: tile.modelData.entry
                size: 36
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, tile.width - 16)
                text: tile.modelData.label || tile.modelData.entry.name
                color: tile.selected ? Theme.text1 : Theme.text2
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.showActions(tile.modelData.entry, tile);
                else
                    root.launch(tile.modelData.entry, tile.modelData.folder);
            }
        }
    }

    component AppRow: Rectangle {
        id: row

        required property var modelData
        required property int index
        readonly property bool selected: root.area === "list" && index === root.listIndex
        readonly property string kind: modelData.kind
        // The entry whose icon it shows: the app, or the window's app
        readonly property var entry: kind === "app" ? modelData.entry : kind === "window" ? DesktopEntries.heuristicLookup(modelData.toplevel.wayland?.appId ?? "") : null
        readonly property string label: {
            if (kind === "app")
                return root.marked(modelData.entry.name, modelData.at);
            if (kind === "window")
                return root.marked(modelData.toplevel.title, modelData.at);
            if (kind === "calc")
                return "= " + modelData.value;
            if (kind === "command")
                return modelData.command === "" ? "Type a command after the >" : "Run <b>" + root.escaped(modelData.command) + "</b>";
            return `Search the web for “${root.escaped(root.query.trim())}”`;
        }
        readonly property string generic: {
            if (kind === "app")
                return modelData.entry.genericName;
            if (kind === "window")
                return root.workspaceLabel(modelData.toplevel.workspace);
            if (kind === "command")
                return "in kitty";
            return kind === "calc" ? "Enter copies it" : "Google";
        }

        width: list.width
        height: 40
        radius: 12
        color: selected ? Theme.active : rowArea.containsMouse ? Theme.hover : "transparent"
        border.width: 1
        border.color: selected ? Theme.purpleGlowStrong : "transparent"

        Item {
            id: rowIcon

            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            AppIcon {
                visible: row.kind === "app" || row.kind === "window"
                entry: row.entry
            }

            MaterialIcon {
                visible: row.kind === "calc" || row.kind === "web" || row.kind === "command"
                anchors.centerIn: parent
                text: row.kind === "calc" ? "calculate" : row.kind === "command" ? "terminal" : "travel_explore"
                color: Theme.accent
            }
        }

        StyledText {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            text: row.label + (row.generic === "" ? "" : `  <i><font color="${Theme.textDim}">${root.escaped(row.generic)}</font></i>`)
            color: row.selected ? Theme.text1 : Theme.text2
            elide: Text.ElideRight
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton && row.kind === "app")
                    root.showActions(row.modelData.entry, row);
                else if (mouse.button === Qt.LeftButton)
                    root.pick(row.modelData);
            }
        }
    }
}
