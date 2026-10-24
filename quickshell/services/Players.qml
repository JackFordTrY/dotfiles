pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// The media player the bar follows: whichever is playing, else the one that played last, else
// the first one around. `follow()` brings a player's window (or browser tab) up.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer lastPlaying: null
    readonly property MprisPlayer active: players.find(p => p.isPlaying) ?? (players.includes(lastPlaying) ? lastPlaying : (players[0] ?? null))

    // "3:07", or "1:02:45" past an hour
    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const secs = String(total % 60).padStart(2, "0");
        return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + secs : minutes + ":" + secs;
    }

    // Brings up what's playing. Players that can raise themselves do; browsers can't (Chromium's
    // MPRIS says CanRaise false), so their window is focused, preferring one whose title (its
    // active tab's) is the track. If no tab showing is the playing one, the tabs are stepped
    // through until the title shows the track, stopping back where it began after a full round
    function follow(player: MprisPlayer) {
        if (!player)
            return;
        if (player.canRaise) {
            player.raise();
            return;
        }
        const track = player.trackTitle;
        // Browsers' players are named after their process: "chromium.instance2779361"
        const pid = Number(player.dbusName.match(/(\d+)$/)?.[1] ?? 0);
        const app = player.identity.toLowerCase();
        const windows = Hyprland.toplevels.values.filter(t => {
            const appId = (t.wayland?.appId || t.lastIpcObject?.class || "").toLowerCase();
            return (app !== "" && appId.includes(app)) || (pid > 0 && t.lastIpcObject?.pid === pid);
        });
        const showing = track === "" ? undefined : windows.find(t => t.title.includes(track));
        const window = showing ?? windows[0];
        if (!window) {
            if (pid > 0)
                Focus.run(["focuswindow pid:" + pid]);
            return;
        }
        Focus.run(["focuswindow address:0x" + window.address]);
        if (!showing && track !== "")
            seeker.start(window, track);
    }

    // Steps a browser window through its tabs until its title shows `track`
    QtObject {
        id: seeker

        property var window: null
        property string track
        // The title it started on, to know a full round has gone by
        property string first
        property int steps: 0

        function start(window: var, track: string) {
            this.window = window;
            this.track = track;
            first = window.title;
            steps = 0;
            next();
        }

        function next() {
            // A safety cap for windows with very many tabs
            if (steps >= 80) {
                stop();
                return;
            }
            steps++;
            Hyprland.dispatch("sendshortcut CTRL, Page_Down, address:0x" + window.address);
            stuck.restart();
        }

        function stop() {
            window = null;
            stuck.stop();
            settle.stop();
        }
    }

    // A tab's title can change more than once as it loads; step on once it's quiet
    Timer {
        id: settle

        interval: 120
        onTriggered: seeker.next()
    }

    // No title change at all: the window didn't take the shortcut
    Timer {
        id: stuck

        interval: 1000
        onTriggered: seeker.stop()
    }

    // windowtitlev2>>ADDRESS,TITLE
    Connections {
        target: Hyprland
        enabled: seeker.window !== null

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "windowtitlev2")
                return;
            const comma = event.data.indexOf(",");
            if (event.data.slice(0, comma) !== seeker.window.address)
                return;
            const title = event.data.slice(comma + 1);
            stuck.stop();
            if (title.includes(seeker.track) || title === seeker.first)
                seeker.stop();
            else
                settle.restart();
        }
    }

    onActiveChanged: {
        if (active?.isPlaying)
            lastPlaying = active;
    }

    // A paused player that starts again becomes the one to come back to
    Connections {
        target: root.active

        function onIsPlayingChanged() {
            if (root.active.isPlaying)
                root.lastPlaying = root.active;
        }
    }
}
