import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// RAM in use: a memory stick that fills from the bottom with the load, its colour climbing from
// cyan through purple and pink to red, and the percentage beside it. Left click brings up
// GNOME Resources floating at 35% x 25% of the screen, in the middle of the current workspace.
TabItem {
    id: root

    readonly property string monitorClass: "org.gnome.Resources"
    // Set while a launched Resources window has yet to appear
    property bool launching: false

    property real load: SystemStats.memory
    readonly property color loadColor: {
        const stops = [[0, Theme.cyan], [0.5, Theme.purple2], [0.75, Theme.pink], [0.9, Theme.red]];
        for (let i = 1; i < stops.length; i++) {
            if (load <= stops[i][0])
                return Theme.mix(stops[i - 1][1], stops[i][1], (load - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]));
        }
        return Theme.red;
    }

    // Resources is single-instance: a running window is brought here, otherwise one is started and
    // placed once it maps
    function openMonitor() {
        const window = Hyprland.toplevels.values.find(t => (t.wayland?.appId || t.lastIpcObject?.class) === monitorClass);
        if (window) {
            place("0x" + window.address);
        } else {
            launching = true;
            Quickshell.execDetached(["resources"]);
        }
    }

    // One batch, so the steps run in order
    function place(address: string) {
        const target = "address:" + address;
        Focus.run(["movetoworkspace " + (Hyprland.focusedWorkspace?.id ?? 1) + "," + target, "setfloating " + target, "resizewindowpixel exact 35% 25%," + target, "focuswindow " + target, "centerwindow"]);
    }

    onClicked: button => {
        if (button === Qt.LeftButton)
            openMonitor();
    }

    // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
    Connections {
        target: Hyprland
        enabled: root.launching

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "openwindow")
                return;
            const [address, , windowClass] = event.data.split(",");
            if (windowClass === root.monitorClass) {
                root.launching = false;
                root.place("0x" + address);
            }
        }
    }

    // Give up waiting if it never shows
    Timer {
        running: root.launching
        interval: 10000
        onTriggered: root.launching = false
    }

    Behavior on load {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: empty.implicitWidth
        height: empty.implicitHeight

        MaterialIcon {
            id: empty

            text: "memory_alt"
            color: root.hovered ? Theme.text2 : Theme.textMuted
        }

        // The filled glyph, clipped to the load. In ems from the icon's top, memory_alt's body
        // spans 0.355-0.845 with pins above and below it down to 0.92 (measured from a render;
        // TextMetrics overstates this glyph's ink). The load fills the body, and the bottom pins
        // always show its colour
        Item {
            readonly property real em: empty.font.pixelSize
            readonly property real bodyTop: 0.355 * em
            readonly property real bodyBottom: 0.845 * em

            y: bodyBottom - root.load * (bodyBottom - bodyTop)
            width: parent.width
            height: 0.92 * em - y
            clip: true

            MaterialIcon {
                y: -parent.y
                text: empty.text
                fill: 1
                color: root.loadColor
            }
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(SystemStats.memory * 100) + "%"
        color: root.hovered ? Theme.text1 : Theme.text2
    }
}
