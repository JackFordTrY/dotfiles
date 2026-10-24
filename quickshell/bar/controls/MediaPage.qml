pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// The media page of the left tab's panel: a big cover beside the track's details, a timeline to
// seek with, the full controls and, for players with their own volume, a slider for it. The
// cover, blurred and dimmed, fills the page behind them.
Item {
    id: root

    // Showing on screen; the position only ticks along while it is
    property bool active
    readonly property MprisPlayer player: Players.active
    readonly property bool playing: player?.isPlaying ?? false
    // The player's own volume, not its stream in the mixer. Browsers advertise one but it's a
    // stub fixed at 100%, so they don't get the slider
    readonly property bool ownVolume: (player?.volumeSupported ?? false) && !/\.(chromium|firefox)/.test(player?.dbusName ?? "")
    readonly property real length: player?.length ?? 0
    readonly property string art: player?.trackArtUrl ?? ""

    implicitHeight: content.implicitHeight + 24

    // Players don't announce their position as they play, so ask while it's on screen
    Timer {
        running: root.active && root.playing
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // The backdrop
    ClippingRectangle {
        anchors.fill: parent
        radius: 14
        color: "transparent"

        Image {
            id: backdrop

            anchors.fill: parent
            source: root.art
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            visible: backdrop.status === Image.Ready
            anchors.fill: parent
            source: backdrop
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.3
            brightness: -0.35
            opacity: 0.45
        }
    }

    Row {
        id: content

        x: 12
        y: 12
        width: parent.width - 24
        spacing: 16

        ClippingRectangle {
            id: cover

            width: 148
            height: 148
            radius: 14
            color: Theme.surface4

            MaterialIcon {
                visible: coverImage.status !== Image.Ready
                anchors.centerIn: parent
                text: "music_note"
                size: 48
                color: Theme.textMuted
            }

            Image {
                id: coverImage

                anchors.fill: parent
                source: root.art
                sourceSize: Qt.size(296, 296)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            width: parent.width - cover.width - parent.spacing
            spacing: 10

            Column {
                width: parent.width
                spacing: 3

                SectionLabel {
                    width: parent.width
                    text: (root.player?.identity ?? "").toUpperCase()
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.player?.trackTitle || root.player?.identity || ""
                    font.pixelSize: 16
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: text !== ""
                    width: parent.width
                    text: root.player?.trackArtist ?? ""
                    color: Theme.text2
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: text !== ""
                    width: parent.width
                    text: root.player?.trackAlbum ?? ""
                    color: Theme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            // Click or drag to seek; the track only jumps on release
            Column {
                opacity: root.length > 0 ? 1 : 0.4
                width: parent.width
                spacing: 2

                StyledSlider {
                    width: parent.width
                    live: false
                    enabled: (root.player?.canSeek ?? false) && root.length > 0
                    value: root.length > 0 ? (root.player?.position ?? 0) / root.length : 0
                    from: Theme.pink
                    to: Theme.purple2
                    onMoved: value => root.player.position = value * root.length
                }

                Item {
                    width: parent.width
                    height: elapsed.implicitHeight

                    StyledText {
                        id: elapsed

                        text: Players.formatTime(root.player?.position ?? 0)
                        color: Theme.textMuted
                        font.pixelSize: 11
                    }

                    StyledText {
                        anchors.right: parent.right
                        text: Players.formatTime(root.length)
                        color: Theme.textMuted
                        font.pixelSize: 11
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                ControlButton {
                    visible: root.player?.shuffleSupported ?? false
                    icon: "shuffle"
                    lit: root.player?.shuffle ?? false
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                ControlButton {
                    icon: "skip_previous"
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.previous()
                }

                // Play/pause, the one big button
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    opacity: root.player?.canTogglePlaying ?? false ? 1 : 0.4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: playArea.containsMouse ? Theme.purple2 : Theme.purple0
                        }
                        GradientStop {
                            position: 1
                            color: Theme.blue
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.playing ? "pause" : "play_arrow"
                        size: 26
                        fill: 1
                        color: "white"
                    }

                    MouseArea {
                        id: playArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: root.player.togglePlaying()
                    }
                }

                ControlButton {
                    icon: "skip_next"
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.next()
                }

                ControlButton {
                    visible: root.player?.loopSupported ?? false
                    icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    lit: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                    // Off, then the playlist, then this track
                    onClicked: {
                        const order = [MprisLoopState.None, MprisLoopState.Playlist, MprisLoopState.Track];
                        root.player.loopState = order[(order.indexOf(root.player.loopState) + 1) % order.length];
                    }
                }
            }

            Row {
                visible: root.ownVolume
                width: parent.width
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.player?.volume ?? 0) === 0 ? "volume_mute" : (root.player?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up"
                    size: 18
                }

                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 38 - parent.spacing * 2
                    value: root.player?.volume ?? 0
                    from: Theme.blue
                    to: Theme.cyan
                    onMoved: value => root.player.volume = value
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((root.player?.volume ?? 0) * 100) + "%"
                    color: Theme.textMuted
                    font.pixelSize: 11
                }
            }
        }
    }

    component ControlButton: Rectangle {
        id: button

        property string icon
        property bool lit: false

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 10
        opacity: enabled ? 1 : 0.4
        color: buttonArea.containsMouse ? Theme.hover : "transparent"

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            size: 22
            fill: button.lit || buttonArea.containsMouse ? 1 : 0
            glow: button.lit ? 0.9 : 0
            color: button.lit ? Theme.accent : buttonArea.containsMouse ? Theme.text1 : Theme.text2
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: button.clicked()
        }
    }
}
