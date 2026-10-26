pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

// Workspaces 1-5 are always shown with an icon for what each is used for; any other regular
// workspace shows its number. Next to it, the icons of the apps open there (three at most, then
// a count). The active one widens into a lit pill with a filled, glowing icon; empty ones are
// dimmed.
Tab {
    id: root

    readonly property var kinds: ({
            1: {
                icon: "home",
                name: "General"
            },
            2: {
                icon: "public",
                name: "Browser"
            },
            3: {
                icon: "code",
                name: "Code"
            },
            4: {
                icon: "terminal",
                name: "Code 2"
            },
            5: {
                icon: "handyman",
                name: "Utilities"
            }
        })

    readonly property var workspaces: {
        const list = Hyprland.workspaces.values.filter(w => !w.name.startsWith("special")).map(w => ({
                    id: w.id,
                    name: w.name
                }));
        for (let id = 1; id <= 5; id++) {
            if (!list.some(w => w.id === id))
                list.push({
                    id: id,
                    name: String(id)
                });
        }
        // numbered by id, then named by name
        return list.sort((a, b) => {
            if (a.id > 0 && b.id > 0)
                return a.id - b.id;
            if ((a.id > 0) !== (b.id > 0))
                return a.id > 0 ? -1 : 1;
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        });
    }

    padding: 5
    spacing: 2

    Repeater {
        model: ScriptModel {
            values: root.workspaces
            objectProp: "id"
        }

        WorkspaceButton {}
    }

    component WorkspaceButton: Item {
        id: button

        required property var modelData
        readonly property var kind: root.kinds[modelData.id] ?? null
        readonly property HyprlandWorkspace workspace: Hyprland.workspaces.values.find(w => w.id === modelData.id) ?? null
        readonly property bool active: Hyprland.focusedWorkspace?.id === modelData.id
        readonly property bool occupied: (workspace?.toplevels.values.length ?? 0) > 0
        readonly property bool urgent: workspace?.urgent ?? false
        readonly property bool hovered: mouse.containsMouse
        readonly property color color: active ? Theme.accent : urgent ? Theme.red : hovered || occupied ? Theme.text2 : Theme.textDim
        // One per app open here, { name, icon }, in the order their windows opened
        readonly property var apps: {
            const seen = new Map();
            for (const window of workspace?.toplevels.values ?? []) {
                const appId = window.wayland?.appId || window.lastIpcObject?.class || "";
                if (appId === "" || seen.has(appId))
                    continue;
                const entry = DesktopEntries.heuristicLookup(appId);
                const icon = entry?.icon ?? appId;
                seen.set(appId, {
                    name: entry?.name ?? appId,
                    icon: icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable")
                });
            }
            return [...seen.values()];
        }
        readonly property int shownApps: Math.min(apps.length, 3)

        implicitWidth: (active ? 56 : 40) + (apps.length === 0 ? 0 : 4 + shownApps * 18 + (apps.length > shownApps ? 18 : 0))
        height: parent.height

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.duration
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 28
            radius: 8
            color: button.active ? Theme.active : button.hovered ? Theme.hover : "transparent"
            border.width: button.active ? 1 : 0
            border.color: Theme.purpleGlowStrong

            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                visible: button.kind !== null
                anchors.verticalCenter: parent.verticalCenter
                text: button.kind?.icon ?? ""
                fill: button.active || button.hovered ? 1 : 0
                glow: button.active ? 0.9 : 0
                color: button.color
            }

            StyledText {
                visible: button.kind === null
                anchors.verticalCenter: parent.verticalCenter
                text: button.modelData.id > 0 ? String(button.modelData.id) : button.modelData.name
                font.bold: true
                color: button.color
            }

            Row {
                visible: button.apps.length > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                opacity: button.active || button.hovered ? 1 : 0.7

                Repeater {
                    model: button.apps.slice(0, button.shownApps)

                    Image {
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: modelData.icon
                        asynchronous: true
                    }
                }

                StyledText {
                    visible: button.apps.length > button.shownApps
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+" + (button.apps.length - button.shownApps)
                    color: button.color
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                tooltip.dismiss();
                Hyprland.dispatch(button.modelData.id > 0 ? "workspace " + button.modelData.id : "workspace name:" + button.modelData.name);
            }
        }

        Tooltip {
            id: tooltip

            target: button
            text: (button.kind?.name ?? "Workspace " + button.modelData.name) + (button.apps.length === 0 ? "" : " · " + button.apps.map(app => app.name).join(", "))
            hovered: mouse.containsMouse
        }
    }
}
