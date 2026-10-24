pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components

// The clipboard history (clipvault; SUPER + V runs `qs ipc call clipboard toggle`). The selected
// image grows into a full preview, easing in and back out as the selection moves. Enter or a click
// puts the entry back on the clipboard, byte for byte, and pastes it into the window that had
// focus: Ctrl+V, or Ctrl+Shift+V in a terminal. Shift+Delete removes it.
Overlay {
    id: root

    // Rows shown at once
    readonly property int rows: 9
    // An image's preview fits in this height
    readonly property real previewHeight: 300
    // Where images are written out of clipvault to be shown
    readonly property string thumbs: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/clipvault/thumbs"
    // Window classes that paste with Ctrl+Shift+V
    readonly property var terminals: ["kitty", "Alacritty", "foot", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "org.kde.konsole"]

    // { id, text, image: { type, file, width, height, size } or null }, newest first
    property var entries: []
    // Image files on disk, by name
    property var cached: ({})
    property int index: 0
    // Where Enter pastes: the window focused when it opened, { address, terminal }
    property var target: null

    // Entries holding every word of the query
    readonly property var results: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        return entries.filter(e => words.every(w => e.text.toLowerCase().includes(w)));
    }

    // "319\t[[ binary data 172kB image/png 966x710 ]]" or "316\tSemantic Kernel"
    function parse(text: string): var {
        return text.split("\n").filter(line => line.includes("\t")).map(line => {
            const tab = line.indexOf("\t");
            const id = line.slice(0, tab);
            const preview = line.slice(tab + 1);
            const image = preview.match(/^\[\[ binary data (\S+) image\/(\w+) (\d+)x(\d+) \]\]$/);
            if (!image)
                return {
                    id: id,
                    text: preview,
                    image: null
                };
            return {
                id: id,
                text: `image ${image[2]} ${image[3]}x${image[4]}`,
                image: {
                    type: "image/" + image[2],
                    file: id + "." + image[2],
                    width: Number(image[3]),
                    height: Number(image[4]),
                    size: image[1].replace(/(\d)([a-zA-Z])/, "$1 $2")
                }
            };
        });
    }

    function step(by: int) {
        index = Math.max(0, Math.min(results.length - 1, index + by));
        list.positionViewAtIndex(index, ListView.Contain);
    }

    // Wayland only lets the focused app paste, so Hyprland sends that window the paste keys
    // once wl-copy holds the entry
    function paste(entry: var) {
        close();
        Quickshell.execDetached(["sh", "-c", 'clipvault get "$1" | wl-copy ${2:+--type "$2"} && [ -n "$3" ] && hyprctl dispatch sendshortcut "$4, V, address:0x$3"', "sh", entry.id, entry.image?.type ?? "", target?.address ?? "", target?.terminal ? "CTRL SHIFT" : "CTRL"]);
    }

    function remove(entry: var) {
        Quickshell.execDetached(["clipvault", "delete", entry.id]);
        entries = entries.filter(e => e.id !== entry.id);
        index = Math.max(0, Math.min(index, results.length - 1));
    }

    WlrLayershell.namespace: "quickshell-clipboard"
    placeholder: "Search clipboard"
    onOpened: {
        const window = Hyprland.activeToplevel;
        target = window ? {
            address: window.address,
            terminal: terminals.includes(window.wayland?.appId || window.lastIpcObject?.class || "")
        } : null;
        index = 0;
        list.positionViewAtBeginning();
        lister.running = true;
    }
    onQueryChanged: {
        index = 0;
        list.positionViewAtBeginning();
    }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:
            step(-1);
            break;
        case Qt.Key_Down:
            step(1);
            break;
        case Qt.Key_PageUp:
            step(-rows);
            break;
        case Qt.Key_PageDown:
            step(rows);
            break;
        case Qt.Key_Delete:
            if (!(event.modifiers & Qt.ShiftModifier))
                return;
            if (results[index])
                remove(results[index]);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (results[index])
                paste(results[index]);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        id: lister

        command: ["clipvault", "list", "--max-preview-width", "200"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parse(text);
                root.index = 0;
                cacher.files = root.entries.filter(e => e.image && !root.cached[e.image.file]).map(e => e.image.file);
                cacher.running = cacher.files.length > 0;
            }
        }
    }

    // Writes out the images not on disk yet ("319.png")
    Process {
        id: cacher

        property var files: []

        command: ["sh", "-c", 'dir=$1; shift; mkdir -p "$dir"; for f; do [ -s "$dir/$f" ] || clipvault get "${f%%.*}" > "$dir/$f"; done', "sh", root.thumbs, ...files]
        onExited: {
            const cached = Object.assign({}, root.cached);
            for (const file of files)
                cached[file] = true;
            root.cached = cached;
        }
    }

    ListView {
        id: list

        width: parent.width
        height: root.rows * 40 + (root.rows - 1) * spacing
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.results
        currentIndex: root.index
        delegate: Entry {}

        StyledText {
            visible: list.count === 0
            anchors.centerIn: parent
            text: root.entries.length === 0 ? "Nothing copied yet" : "No matches"
            color: Theme.textDim
        }
    }

    component Entry: Item {
        id: entry

        required property var modelData
        required property int index
        readonly property var image: modelData.image
        readonly property bool selected: index === root.index
        readonly property string file: image && root.cached[image.file] ? "file://" + root.thumbs + "/" + image.file : ""
        // The preview: the image fitted to the row's width and previewHeight, never enlarged
        readonly property real fit: image ? Math.min(1, (width - 20) / image.width, root.previewHeight / image.height) : 0
        readonly property real bigWidth: image ? image.width * fit : 0
        readonly property real bigHeight: image ? image.height * fit : 0
        // 0 a row, 1 the full preview
        property real grown: selected && image ? 1 : 0

        function mix(from: real, to: real): real {
            return from + (to - from) * grown;
        }

        width: list.width
        height: mix(40, 50 + bigHeight)
        // Keeps the growing preview in view
        onHeightChanged: {
            if (selected)
                list.positionViewAtIndex(index, ListView.Contain);
        }

        Behavior on grown {
            NumberAnimation {
                duration: 320
                easing.type: Easing.InOutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: entry.selected ? Theme.active : area.containsMouse ? Theme.hover : "transparent"
            border.width: 1
            border.color: entry.selected ? Theme.purpleGlowStrong : "transparent"
        }

        // The thumbnail, growing into the preview under the caption. It drops below the caption's
        // line in the first quarter, so the two don't overlap while it grows
        Item {
            x: entry.mix(10, (entry.width - entry.bigWidth) / 2)
            y: 6 + 34 * Math.min(1, entry.grown * 4)
            width: entry.image ? entry.mix(40, entry.bigWidth) : 40
            height: entry.image ? entry.mix(28, entry.bigHeight) : 28

            Image {
                visible: entry.image !== null
                anchors.fill: parent
                source: entry.file
                sourceSize.width: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // Sharp at full size; loaded while it grows and fading in over the thumbnail
            Image {
                anchors.fill: parent
                source: entry.grown > 0 ? entry.file : ""
                sourceSize.width: entry.bigWidth * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                visible: entry.image !== null
                anchors.fill: parent
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: Theme.purpleGlow
            }

            MaterialIcon {
                visible: entry.image === null
                anchors.centerIn: parent
                text: "notes"
                size: 18
                color: Theme.textMuted
            }
        }

        StyledText {
            x: entry.image ? entry.mix(62, 12) : 62
            y: (40 - height) / 2
            width: entry.width - x - 12
            textFormat: entry.image ? Text.StyledText : Text.PlainText
            text: entry.image ? `Image  <font color="${Theme.textDim}">${entry.image.width} × ${entry.image.height} · ${entry.image.size}</font>` : entry.modelData.text
            color: entry.selected ? Theme.text1 : Theme.text2
            elide: Text.ElideRight
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.paste(entry.modelData)
        }
    }
}
