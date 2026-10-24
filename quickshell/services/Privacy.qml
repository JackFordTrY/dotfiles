pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// What's recording right now: apps capturing the microphone (Pipewire input streams), apps taking
// video (a shared screen or the camera, as Pipewire video streams), and whether the screen is
// being cast (Hyprland's screencast event, which also covers recorders that don't go through
// Pipewire). The overview's own live previews count as a screencast to Hyprland, so it says when
// they're up.
Singleton {
    id: root

    // Hyprland's screencast>>STATE,OWNER
    property bool screencast: false
    // Set by the overview while its previews run. The cast they start is left out until Hyprland
    // says it's over, which comes a moment after the overview closes
    property bool selfCapturing: false
    property bool ownCast: false

    readonly property var micStreams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream)
    readonly property var videoStreams: Pipewire.nodes.values.filter(n => (n.type & PwNodeType.Video) && (n.type & PwNodeType.Stream))
    readonly property var micApps: [...new Set(micStreams.map(n => Audio.appName(n)))]
    readonly property var videoApps: [...new Set(videoStreams.map(n => Audio.appName(n)))]
    readonly property bool screenShared: screencast && !ownCast
    // Video taken while the screen isn't being cast is the camera
    readonly property bool cameraUsed: videoStreams.length > 0 && !screenShared
    readonly property bool active: micStreams.length > 0 || videoStreams.length > 0 || screenShared

    onSelfCapturingChanged: {
        if (selfCapturing)
            ownCast = true;
        else if (!screencast)
            ownCast = false;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "screencast")
                return;
            root.screencast = event.data.split(",")[0] === "1";
            if (!root.screencast && !root.selfCapturing)
                root.ownCast = false;
        }
    }

    // The app names come from the streams' properties
    PwObjectTracker {
        objects: [...root.micStreams, ...root.videoStreams]
    }
}
