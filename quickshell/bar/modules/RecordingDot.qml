import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Something is recording: a pulsing red dot and what's being taken (the mic, the screen, the
// camera), with the apps in the tooltip. Hidden otherwise. A click brings up the first app's
// window.
TabItem {
    id: root

    visible: Privacy.active
    tooltip: [Privacy.micApps.length > 0 ? "Microphone: " + Privacy.micApps.join(", ") : "", Privacy.screenShared ? "Screen: " + (Privacy.videoApps.join(", ") || "being cast") : "", Privacy.cameraUsed ? "Camera: " + Privacy.videoApps.join(", ") : ""].filter(line => line !== "").join("\n")
    onClicked: button => {
        if (button !== Qt.LeftButton)
            return;
        // The stream's program, matched against the windows' apps ("discord", "opera")
        const stream = Privacy.micStreams[0] ?? Privacy.videoStreams[0];
        const binary = (stream?.properties?.["application.process.binary"] ?? "").toLowerCase();
        const window = binary === "" ? undefined : Hyprland.toplevels.values.find(t => (t.wayland?.appId ?? "").toLowerCase().includes(binary));
        if (window)
            Focus.run(["focuswindow address:0x" + window.address]);
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: Theme.red

        SequentialAnimation on opacity {
            running: root.visible
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.35
                duration: 700
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 700
                easing.type: Easing.InOutSine
            }
        }
    }

    MaterialIcon {
        visible: Privacy.micApps.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: "mic"
        fill: 1
        color: Theme.red
    }

    MaterialIcon {
        visible: Privacy.screenShared || Privacy.cameraUsed
        anchors.verticalCenter: parent.verticalCenter
        text: Privacy.screenShared ? "screen_record" : "videocam"
        fill: 1
        color: Theme.red
    }
}
