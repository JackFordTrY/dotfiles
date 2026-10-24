import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// The title of what's playing with a bouncing equalizer; the controls live in the left tab's
// panel. A click brings up the player (for a browser, its window and the playing tab). Shown
// while something plays, dimmed for a few minutes after it's paused (so it can be resumed from
// the panel), and while `pinned` (the panel is open on it).
Item {
    id: root

    readonly property MprisPlayer player: Players.active
    property bool pinned: false
    // Paused less than `linger` ago
    property bool lingering: false
    readonly property int linger: 3 * 60 * 1000
    readonly property bool playing: player?.isPlaying ?? false
    readonly property alias hovered: hover.hovered

    visible: player !== null && (playing || lingering || pinned)
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
    implicitWidth: row.implicitWidth + 16
    height: parent.height

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Players.follow(root.player)
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

        Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            playing: root.playing
        }
    }
}
