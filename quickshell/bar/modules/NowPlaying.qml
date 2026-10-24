import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// The title of what's playing with a bouncing equalizer; the controls live in the left tab's
// panel. A click brings up the player (for a browser, its window and the playing tab), and
// scrolling sets its volume, the equalizer showing the level meanwhile. Shown while something
// plays, dimmed for a few minutes after it's paused (so it can be resumed from the panel), and
// while `pinned` (the panel is open on it).
Item {
    id: root

    readonly property MprisPlayer player: Players.active
    property bool pinned: false
    // Paused less than `linger` ago
    property bool lingering: false
    readonly property int linger: 3 * 60 * 1000
    readonly property bool playing: player?.isPlaying ?? false
    readonly property alias hovered: hover.hovered

    // The player's own volume where it has a real one (as the media page decides); browsers
    // advertise one stuck at 100%, so theirs is the app's stream in the mixer
    readonly property bool ownVolume: (player?.volumeSupported ?? false) && !/\.(chromium|firefox)/.test(player?.dbusName ?? "")
    readonly property PwNode stream: {
        const name = (player?.identity ?? "").toLowerCase();
        if (ownVolume || name === "")
            return null;
        return Audio.streams.find(s => Audio.appName(s).toLowerCase() === name) ?? Audio.streams.find(s => Audio.appName(s).toLowerCase().includes(name)) ?? null;
    }
    readonly property real volume: ownVolume ? player.volume : stream?.audio?.volume ?? 0
    property bool showingVolume: false
    property real wheelDelta: 0

    function nudge(by: real) {
        const level = Math.max(0, Math.min(1, volume + by));
        if (ownVolume)
            player.volume = level;
        else if (stream)
            Audio.setVolume(stream, level);
        else
            return;
        showingVolume = true;
        volumeShown.restart();
    }

    visible: player !== null && (playing || lingering || pinned)
    implicitWidth: row.implicitWidth + 16
    height: parent.height
    onPlayingChanged: {
        lingering = !playing;
        if (lingering)
            lingerTimer.restart();
    }

    Timer {
        id: lingerTimer

        interval: root.linger
        onTriggered: root.lingering = false
    }

    Timer {
        id: volumeShown

        interval: 1200
        onTriggered: root.showingVolume = false
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Players.follow(root.player)
    }

    // 5% a notch; a touchpad's small steps add up to notches
    WheelHandler {
        onWheel: event => {
            root.wheelDelta += event.angleDelta.y;
            const steps = Math.trunc(root.wheelDelta / 120);
            if (steps !== 0) {
                root.wheelDelta -= steps * 120;
                root.nudge(steps * 0.05);
            }
        }
    }

    Row {
        id: row

        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 220)
            text: root.player?.trackTitle || root.player?.identity || ""
            color: root.hovered ? Theme.text1 : root.playing ? Theme.text2 : Theme.textMuted
            elide: Text.ElideRight
        }

        // Room for "100%", so the tab doesn't change width while scrolling
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 20

            Equalizer {
                visible: !root.showingVolume
                anchors.centerIn: parent
                playing: root.playing
            }

            StyledText {
                visible: root.showingVolume
                anchors.centerIn: parent
                text: Math.round(root.volume * 100) + "%"
                color: Theme.text1
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
