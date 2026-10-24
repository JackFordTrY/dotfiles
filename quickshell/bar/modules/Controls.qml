pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.bar.controls

// The right tab: a red dot while something records, the notification bell, language, the Wi-Fi /
// Bluetooth / volume icons, battery, power and clock. Hovering or clicking one of those three
// icons grows the tab into a panel with a tile for each (the tile's icon switches it on and off,
// the rest of the tile picks its page), a brightness slider, that page, and the system tray along
// the bottom; hovering the bell shows the notification history there, and hovering the clock the
// month. Clicking power shrinks it to just the power options.
Popout {
    id: root

    // wifi | bluetooth | sound | notifications | calendar | power
    property string page: "sound"
    // Every page but power gets this much room, so switching between them never resizes the
    // panel; the lists scroll inside it
    readonly property real pageHeight: 250
    // Power is a single row of icons, without the tiles and tray
    readonly property real bodyHeight: page === "power" ? powerPage.implicitHeight : sections.implicitHeight
    // The bar's window is sized for the taller one, so switching never resizes it
    readonly property real maxHeight: Math.max(sections.implicitHeight, powerPage.implicitHeight) + 28 + Theme.tabHeight
    readonly property bool wantsKeyboard: open && page === "wifi" && wifiPage.wantsKeyboard
    readonly property string hoveredPage: bell.hovered ? "notifications" : clock.hovered ? "calendar" : network.hovered ? "wifi" : bluetooth.hovered ? "bluetooth" : volume.hovered ? "sound" : ""

    function showPage(name: string) {
        page = name;
        show();
    }

    growOrigin: 1
    expandedWidth: 420
    expandedHeight: bodyHeight + 28 + Theme.tabHeight
    trigger: status.hovered || bell.hovered || clock.hovered
    // Also stays open under a tray menu or the bell's menu
    pinned: wantsKeyboard || tray.menuOpen || bell.menuOpen
    onHoveredPageChanged: {
        if (hoveredPage !== "" && !wantsKeyboard)
            page = hoveredPage;
    }
    // The backlight may have moved without the keys (another app, a dimmer)
    onOpenChanged: {
        if (open)
            Brightness.refresh();
    }

    Behavior on expandedHeight {
        enabled: root.open

        NumberAnimation {
            duration: Theme.openDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasized
        }
    }

    body: Item {
        x: 16
        y: 14
        width: root.openWidth - 32
        height: root.bodyHeight

        PageSlot {
            shown: root.page !== "power"

            Column {
                id: sections

                width: parent.width
                spacing: 14

                Row {
                    id: tiles

                    readonly property real tileWidth: (width - spacing * 2) / 3

                    width: parent.width
                    spacing: 8

                    Tile {
                        width: tiles.tileWidth
                        icon: wifiPage.powered ? "wifi" : "wifi_off"
                        title: "Wi-Fi"
                        subtitle: {
                            if (!wifiPage.powered)
                                return "Off";
                            return wifiPage.networks.find(n => n.connected)?.name ?? "Not connected";
                        }
                        on: wifiPage.powered
                        selected: root.page === "wifi"
                        onToggled: wifiPage.setPowered(!wifiPage.powered)
                        onPicked: root.page = "wifi"
                    }

                    Tile {
                        width: tiles.tileWidth
                        icon: bluetoothPage.powered ? "bluetooth" : "bluetooth_disabled"
                        title: "Bluetooth"
                        subtitle: {
                            if (!bluetoothPage.powered)
                                return "Off";
                            const connected = bluetoothPage.devices.filter(d => d.connected);
                            return connected.length === 0 ? "On" : connected.length === 1 ? connected[0].name : connected.length + " devices";
                        }
                        on: bluetoothPage.powered
                        selected: root.page === "bluetooth"
                        onToggled: {
                            if (bluetoothPage.adapter)
                                bluetoothPage.adapter.enabled = !bluetoothPage.adapter.enabled;
                        }
                        onPicked: root.page = "bluetooth"
                    }

                    Tile {
                        readonly property bool muted: Audio.sink?.audio?.muted ?? false

                        width: tiles.tileWidth
                        icon: muted ? "volume_off" : "volume_up"
                        title: "Sound"
                        subtitle: muted ? "Muted" : Audio.sinkName(Audio.sink)
                        on: !muted
                        selected: root.page === "sound"
                        onToggled: Audio.toggleMute(Audio.sink)
                        onPicked: root.page = "sound"
                    }
                }

                // The backlight, under the tiles on every page; laid out like the sound page's rows
                Item {
                    visible: Brightness.available
                    width: parent.width
                    height: 30

                    Item {
                        id: brightnessIcon

                        width: 30
                        height: 30

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Brightness.value < 0.34 ? "brightness_low" : Brightness.value < 0.67 ? "brightness_medium" : "brightness_high"
                            color: Theme.text2
                        }
                    }

                    StyledText {
                        id: brightnessLabel

                        anchors.left: brightnessIcon.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 104
                        text: "Brightness"
                        color: Theme.text2
                        font.pixelSize: 13
                    }

                    StyledSlider {
                        anchors.left: brightnessLabel.right
                        anchors.leftMargin: 8
                        anchors.right: brightnessPercent.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        value: Brightness.value
                        from: Theme.pink
                        to: Theme.yellow
                        onMoved: value => Brightness.set(value)
                    }

                    StyledText {
                        id: brightnessPercent

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(Brightness.value * 100) + "%"
                        color: Theme.text2
                        font.pixelSize: 12
                    }
                }

                // The pages share one slot and cross-fade. They stay loaded while hidden: the tiles read
                // their state from them
                Item {
                    width: parent.width
                    height: root.pageHeight

                    PageSlot {
                        shown: root.page === "wifi"

                        WifiPage {
                            id: wifiPage

                            anchors.fill: parent
                            active: root.page === "wifi" && root.open
                        }
                    }

                    PageSlot {
                        shown: root.page === "bluetooth"

                        BluetoothPage {
                            id: bluetoothPage

                            anchors.fill: parent
                            active: root.page === "bluetooth" && root.open
                        }
                    }

                    PageSlot {
                        shown: root.page === "sound"

                        SoundPage {
                            anchors.fill: parent
                        }
                    }

                    PageSlot {
                        shown: root.page === "notifications"

                        NotificationsPage {
                            anchors.fill: parent
                            active: root.page === "notifications" && root.open
                        }
                    }

                    PageSlot {
                        shown: root.page === "calendar"

                        CalendarPage {
                            anchors.fill: parent
                            active: root.page === "calendar" && root.open
                        }
                    }
                }

                // Next to the bar, so it's quick to reach whichever page is showing. One row; a full
                // tray scrolls sideways rather than growing the panel
                Column {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.purpleGlow
                    }

                    Item {
                        width: parent.width
                        height: 32

                        SectionLabel {
                            id: trayLabel

                            anchors.verticalCenter: parent.verticalCenter
                            text: "TRAY"
                        }

                        StyledText {
                            visible: tray.count === 0
                            anchors.left: trayLabel.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Empty"
                            color: Theme.textDim
                            font.pixelSize: 12
                        }

                        Flickable {
                            anchors.left: trayLabel.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            height: parent.height
                            contentWidth: tray.width
                            interactive: contentWidth > width
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            Tray {
                                id: tray

                                height: parent.height
                            }
                        }
                    }
                }
            }
        }

        PageSlot {
            shown: root.page === "power"

            PowerPage {
                id: powerPage

                width: parent.width
                active: root.open && root.page === "power"
                onRan: root.open = false
            }
        }
    }

    // Only while something records the mic, screen or camera
    RecordingDot {
        id: recording
    }

    Divider {
        visible: recording.visible
    }

    Bell {
        id: bell

        active: root.open && root.page === "notifications"
    }

    Language {}

    Divider {}

    // The panel's trigger
    Row {
        id: status

        readonly property alias hovered: statusHover.hovered

        height: parent.height

        HoverHandler {
            id: statusHover
        }

        Network {
            id: network

            active: root.open && root.page === "wifi"
            onClicked: button => {
                if (button === Qt.LeftButton)
                    root.showPage("wifi");
            }
        }

        Bluetooth {
            id: bluetooth

            active: root.open && root.page === "bluetooth"
            onClicked: button => {
                if (button === Qt.LeftButton)
                    root.showPage("bluetooth");
            }
        }

        Volume {
            id: volume

            active: root.open && root.page === "sound"
            onClicked: button => {
                if (button === Qt.LeftButton)
                    root.showPage("sound");
            }
        }
    }

    Divider {}

    Battery {}

    Divider {}

    Power {
        active: root.open && root.page === "power"
        onClicked: button => {
            if (button !== Qt.LeftButton)
                return;
            if (active)
                root.open = false;
            else
                root.showPage("power");
        }
    }

    Divider {}

    Clock {
        id: clock

        active: root.open && root.page === "calendar"
        onClicked: button => {
            if (button === Qt.LeftButton)
                root.showPage("calendar");
        }
    }
}
