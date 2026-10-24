pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components

// Nearby networks, scanned while the page is showing: the current one first, then saved ones,
// then by signal. Clicking connects or disconnects; a new secured network asks for its password
// right here.
Column {
    id: root

    // Scan while true
    property bool active
    readonly property bool powered: Networking.wifiEnabled
    readonly property WifiDevice device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var networks: (device?.networks.values ?? []).filter(n => n.name !== "").sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    // The network waiting for a password
    property WifiNetwork entering: null
    property string error
    readonly property bool wantsKeyboard: entering !== null

    function setPowered(on: bool) {
        Networking.wifiEnabled = on;
    }

    function activate(network: WifiNetwork) {
        error = "";
        if (network.connected) {
            network.disconnect();
        } else if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
            network.connect();
        } else if ([WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security)) {
            entering = network;
            password.text = "";
            password.forceActiveFocus();
        } else {
            // Enterprise logins need more than a password
            Quickshell.execDetached(["kitty", "-e", "nmtui", "connect", network.name]);
        }
    }

    function submit() {
        if (entering && password.text !== "")
            entering.connectWithPsk(password.text);
        entering = null;
    }

    function signalIcon(strength: real): string {
        return strength >= 0.75 ? "signal_wifi_4_bar" : "network_wifi_" + (strength >= 0.5 ? 3 : strength >= 0.25 ? 2 : 1) + "_bar";
    }

    spacing: 6
    onActiveChanged: {
        if (!active)
            entering = null;
    }

    Binding {
        when: root.active && root.device !== null
        target: root.device
        property: "scannerEnabled"
        value: true
    }

    SectionLabel {
        text: "NETWORKS"
    }

    StyledText {
        visible: !root.powered
        text: Networking.wifiHardwareEnabled ? "Wi-Fi is off" : "Wi-Fi is blocked by the hardware switch"
        color: Theme.textDim
        font.pixelSize: 13
    }

    StyledText {
        visible: root.powered && root.networks.length === 0
        text: "Looking for networks…"
        color: Theme.textDim
        font.pixelSize: 13
    }

    // Fills the page's room above the password row, then scrolls
    Flickable {
        visible: root.powered && root.networks.length > 0
        width: parent.width
        height: Math.min(list.height, root.height - y - (passwordBox.visible ? passwordBox.height + root.spacing : 0) - (errorText.visible ? errorText.implicitHeight + root.spacing : 0))
        contentHeight: list.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: root.networks
                }

                ListEntry {
                    id: entry

                    required property WifiNetwork modelData

                    icon: root.signalIcon(modelData?.signalStrength ?? 0)
                    text: modelData?.name ?? ""
                    active: modelData?.connected ?? false
                    busy: modelData?.stateChanging ?? false
                    detail: modelData?.stateChanging ? (modelData?.connected ? "Disconnecting…" : "Connecting…") : modelData?.connected ? "Connected" : modelData?.known ? "Saved" : ""
                    onClicked: button => {
                        if (button === Qt.LeftButton)
                            root.activate(modelData);
                    }

                    MaterialIcon {
                        visible: entry.modelData?.security !== WifiSecurityType.Open && entry.modelData?.security !== WifiSecurityType.Owe
                        text: "lock"
                        size: 14
                        color: Theme.textDim
                    }

                    Connections {
                        target: entry.modelData

                        function onConnectionFailed(reason: int) {
                            if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout) {
                                root.error = "Couldn't join " + entry.modelData?.name + ", check the password";
                                root.entering = entry.modelData;
                                password.text = "";
                                password.forceActiveFocus();
                            } else {
                                root.error = "Couldn't join " + entry.modelData?.name;
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: passwordBox

        visible: root.entering !== null
        width: parent.width
        height: 36
        radius: 10
        color: Theme.raised
        border.width: 1
        border.color: password.activeFocus ? Theme.purpleGlowStrong : Theme.purpleGlow

        MaterialIcon {
            id: keyIcon

            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "key"
            color: Theme.textMuted
        }

        TextInput {
            id: password

            anchors.left: keyIcon.right
            anchors.leftMargin: 10
            anchors.right: joinButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: Theme.text1
            selectionColor: Theme.purple0
            font.family: Theme.font
            font.pixelSize: 13
            clip: true
            onAccepted: root.submit()
            Keys.onEscapePressed: root.entering = null

            StyledText {
                visible: password.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "Password for " + (root.entering?.name ?? "")
                color: Theme.textDim
                font.pixelSize: 13
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Rectangle {
            id: joinButton

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 8
            color: joinArea.containsMouse ? Qt.alpha(Theme.purple0, 0.55) : Qt.alpha(Theme.purple0, 0.38)

            MaterialIcon {
                anchors.centerIn: parent
                text: "arrow_forward"
                size: 18
                color: Theme.text1
            }

            MouseArea {
                id: joinArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: root.submit()
            }
        }
    }

    StyledText {
        id: errorText

        visible: root.error !== ""
        width: parent.width
        text: root.error
        color: Theme.red
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
}
