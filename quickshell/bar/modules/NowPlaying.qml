import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// The title of what's playing with a bouncing equalizer; the controls live in the left tab's
// panel. A click brings up the player (for a browser, its window and the playing tab). Shown
// while something plays, and while `pinned` (the panel is open on it) so pausing from the panel
// doesn't take it away mid-use.
Item {
    id: root

    readonly property MprisPlayer player: Players.active
    property bool pinned: false
    readonly property alias hovered: hover.hovered

    visible: player !== null && (player.isPlaying || pinned)
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
            color: root.hovered ? Theme.text1 : Theme.text2
            elide: Text.ElideRight
        }

        Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            playing: root.player?.isPlaying ?? false
        }
    }
}
