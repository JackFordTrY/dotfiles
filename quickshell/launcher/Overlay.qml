pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components

// A panel in the middle of the screen with a search field on top, for the launcher, the clipboard
// picker and the overview; children go under the field, `above` over everything (menus). It
// covers the whole screen while open, so a click outside the panel closes it, and is mapped only
// while open and fading out. Keys go to `keyPressed` first; Escape closes it unless that took it.
PanelWindow {
    id: root

    property bool open: false
    property string placeholder: "Search"
    property real panelWidth: 640
    // Quicker than the bar's panels: it's summoned from the keyboard and should be there at once
    readonly property int openDuration: 140
    readonly property int closeDuration: 90
    readonly property string query: search.text
    default property alias content: column.data
    property alias above: above.data

    // Before it shows, with the query cleared
    signal opened
    // Set `event.accepted` to keep it from the search field
    signal keyPressed(var event)

    function show() {
        root.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        search.text = "";
        opened();
        open = true;
        search.forceActiveFocus();
    }

    function close() {
        open = false;
    }

    function toggle() {
        if (open)
            close();
        else
            show();
    }

    visible: open || card.opacity > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Clicks go through once it's closing
    mask: Region {
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: root.panelWidth
        height: column.implicitHeight + 28
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? root.openDuration : root.closeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.open ? Theme.emphasized : Theme.emphasizedAccel
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.open ? root.openDuration : root.closeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.open ? Theme.emphasized : Theme.emphasizedAccel
            }
        }

        FloatingPanel {
            anchors.fill: parent
        }

        // Clicks on the panel itself don't close it
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: Theme.raised
                border.width: 1
                border.color: Theme.purpleGlow

                MaterialIcon {
                    id: searchIcon

                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    color: Theme.accent
                }

                TextInput {
                    id: search

                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text1
                    selectionColor: Theme.purple0
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    clip: true
                    focus: true
                    Keys.onPressed: event => {
                        root.keyPressed(event);
                        if (!event.accepted && event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                        }
                    }

                    StyledText {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.placeholder
                        color: Theme.textDim
                    }
                }
            }
        }

        Item {
            id: above

            anchors.fill: parent
        }
    }
}
