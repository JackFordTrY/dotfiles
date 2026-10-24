pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components

// The app launcher (SUPER + R runs `qs ipc call launcher toggle`): a row of pinned apps and every
// app, most launched first, under the search field. Left and Right cycle round the pinned apps
// (the row scrolls when they don't fit), Up and Down go through the list, typing searches it and
// Enter launches the selection. Arithmetic ("2*21") shows its result on top, which Enter copies;
// when no app matches, Enter searches the web. Escape, SUPER + R again or a click outside the
// panel closes it.
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

    // Where the arrows and Enter act: "pinned" or "list"
    property string area: "pinned"
    property int pinnedIndex: 0
    property int listIndex: 0
    // Launch counts rofi kept (~/.cache/rofi3.druncache, left behind when it was removed), so the
    // order it learned carries over; the launcher's own counts add to them
    property var rofiUses: ({})

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

    // What the list shows: the result first when the query is arithmetic, then the apps, then a
    // web search when no app matches
    readonly property var rows: {
        const q = query.trim();
        const answer = calculate(q);
        return [...(answer === null ? [] : [
                    {
                        kind: "calc",
                        value: answer
                    }
                ]), ...results, ...(q !== "" && results.length === 0 ? [
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
        close();
        if (row.kind === "calc")
            Quickshell.execDetached(["wl-copy", row.value]);
        else
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(query.trim())]);
    }

    function launch(entry: var, folder: string) {
        close();
        const uses = Object.assign({}, counts.uses);
        uses[entry.id] = (uses[entry.id] ?? 0) + 1;
        counts.uses = uses;
        store.writeAdapter();
        if (folder === "") {
            entry.execute();
            return;
        }
        // `command` comes without the Exec line's field codes (%F)
        Quickshell.execDetached([...entry.command, Quickshell.env("HOME") + "/" + folder]);
    }

    WlrLayershell.namespace: "quickshell-launcher"
    onOpened: {
        area = "pinned";
        pinnedIndex = 0;
        listIndex = 0;
        pinnedView.positionViewAtBeginning();
        list.positionViewAtBeginning();
    }
    onQueryChanged: {
        area = query.trim() === "" ? "pinned" : "list";
        listIndex = 0;
        list.positionViewAtBeginning();
    }
    onKeyPressed: event => {
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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launch(tile.modelData.entry, tile.modelData.folder)
        }
    }

    component AppRow: Rectangle {
        id: row

        required property var modelData
        required property int index
        readonly property bool selected: root.area === "list" && index === root.listIndex
        readonly property bool app: modelData.kind === "app"
        readonly property string generic: app ? modelData.entry.genericName : modelData.kind === "calc" ? "Enter copies it" : "Google"

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
                visible: row.app
                entry: row.app ? row.modelData.entry : null
            }

            MaterialIcon {
                visible: !row.app
                anchors.centerIn: parent
                text: row.modelData.kind === "calc" ? "calculate" : "travel_explore"
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
            text: {
                const name = row.app ? root.marked(row.modelData.entry.name, row.modelData.at) : row.modelData.kind === "calc" ? "= " + row.modelData.value : `Search the web for “${root.escaped(root.query.trim())}”`;
                return name + (row.generic === "" ? "" : `  <i><font color="${Theme.textDim}">${root.escaped(row.generic)}</font></i>`);
            }
            color: row.selected ? Theme.text1 : Theme.text2
            elide: Text.ElideRight
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pick(row.modelData)
        }
    }
}
