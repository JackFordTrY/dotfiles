pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Output devices, the default output and mic, and the apps currently playing audio, with names
// and icons for the apps. Everything listed is tracked so its volume can be read and set.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink && n.audio)
    // Playback streams; an app's recording streams (Discord's mic capture) are left out
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)

    function setVolume(node: PwNode, volume: real) {
        if (!node?.audio)
            return;
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, volume));
    }

    function toggleMute(node: PwNode) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    function setSink(node: PwNode) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // The desktop entry behind a stream; apps like Discord name their streams after the audio
    // engine ("WEBRTC VoiceEngine"), so the process binary is the better key
    function entryFor(stream: PwNode): var {
        const props = stream?.properties ?? {};
        const key = props["application.process.binary"] || props["application.name"] || "";
        // Reading the list re-runs the callers' bindings once the entries have loaded
        if (key === "" || DesktopEntries.applications.values.length === 0)
            return null;
        return DesktopEntries.heuristicLookup(key);
    }

    function appName(stream: PwNode): string {
        const props = stream?.properties ?? {};
        return entryFor(stream)?.name || props["application.name"] || stream?.description || stream?.name || "Unknown";
    }

    function appIcon(stream: PwNode): string {
        const props = stream?.properties ?? {};
        const icon = entryFor(stream)?.icon || props["application.icon-name"] || props["application.process.binary"] || "";
        return icon === "" ? "" : Quickshell.iconPath(icon, true);
    }

    // "Speaker", "Headphones", or a Bluetooth device's own name
    function sinkName(node: PwNode): string {
        if (!node)
            return "No output";
        if (/bluez/.test(node.name))
            return node.description;
        const text = (node.description + " " + node.name).toLowerCase();
        if (text.includes("hdmi") || text.includes("displayport"))
            return "Display";
        if (text.includes("headphone") || text.includes("headset"))
            return "Headphones";
        return text.includes("speaker") ? "Speaker" : node.nickname || node.description;
    }

    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.streams]
    }
}
