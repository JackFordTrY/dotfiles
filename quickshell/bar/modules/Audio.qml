import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// pulseaudio: "{icon} {volume}%" with Waybar's port-based icons and its bluetooth/muted
// formats. Scrolling steps the volume by 1% up to 100%; left click opens pavucontrol.
Module {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool bluetooth: /a2dp_sink|a2dp-sink|bluez/.test(sink?.name ?? "")

    // format-icons: a port/form-factor match wins, otherwise the default list by volume
    readonly property string icon: {
        const icons = {
            "headphone": "",
            "hands-free": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": ""
        };
        const name = (AudioPorts.portName + AudioPorts.formFactor).toLowerCase();
        const port = ["headphone", "speaker", "hdmi", "headset", "hands-free", "portable", "car", "hifi", "phone"].find(p => name.includes(p));
        return icons[port] ?? ["", " ", " "][Math.min(2, Math.trunc(volume / 33))];
    }

    readonly property string formatSource: source?.audio?.muted ? "" : Math.round((source?.audio?.volume ?? 0) * 100) + "% "

    readonly property string text: {
        if (bluetooth)
            return (muted ? "" : volume + "%") + "  " + icon + " " + formatSource;
        return muted ? "  " + formatSource : icon + " " + volume + "%";
    }

    pill: true
    marginRight: 15
    padLeft: 10
    padRight: 10
    background: muted ? Theme.moduleBgAlt : Theme.moduleBg
    tooltip: sink?.description ?? ""
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["pavucontrol"]);
    }
    onScrolled: steps => {
        if (sink?.audio)
            sink.audio.volume = Math.min(100, Math.max(0, volume + steps)) / 100;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Label {
        text: root.text
        color: root.muted ? Theme.text1 : Theme.text2
    }
}
