import QtQuick
import qs.config
import qs.components
import qs.services

// Output volume. Scrolling steps it by 1% up to 100% and right click toggles mute; the sound
// page of the controls panel has the rest. Headphone ports and Bluetooth sinks get a
// headphones icon.
TabItem {
    readonly property int volume: Math.round((Audio.sink?.audio?.volume ?? 0) * 100)
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property bool headphones: {
        const port = (AudioPorts.portName + AudioPorts.formFactor).toLowerCase();
        return /a2dp_sink|a2dp-sink|bluez/.test(Audio.sink?.name ?? "") || ["headphone", "headset", "hands-free"].some(p => port.includes(p));
    }

    icon: {
        if (muted)
            return "volume_off";
        if (headphones)
            return "headphones";
        return volume === 0 ? "volume_mute" : volume < 50 ? "volume_down" : "volume_up";
    }
    text: volume + "%"
    iconColor: muted ? Theme.red : Theme.text2
    textColor: muted ? Theme.textDim : Theme.text2
    onClicked: button => {
        if (button === Qt.RightButton)
            Audio.toggleMute(Audio.sink);
    }
    onScrolled: steps => {
        if (Audio.sink?.audio)
            Audio.sink.audio.volume = Math.min(100, Math.max(0, volume + steps)) / 100;
    }
}
