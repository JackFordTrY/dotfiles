pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon. Every notification goes into `history` (newest first, saved across
// restarts, kept until cleared from the panel) and, unless `silenced`, into `popups` for the
// banners that drop from the top edge. Entries are plain objects copying a notification's text
// so they outlive it; `notification` stays set while the app's notification is alive, for its
// actions. Bindings that should follow a replaced notification read through `notification`
// rather than the copies.
//
// `qs ipc call notifications toggleSilence` and `... clear` are there for keybindings.
Singleton {
    id: root

    property bool silenced: false
    // Set by new arrivals, cleared once the history has been looked at
    property bool unread: false
    property var history: []
    property var popups: []
    // Only a safety cap; past it the oldest entries go
    readonly property int maxHistory: 200
    readonly property int maxPopups: 3
    // Saving waits for the history to load, or it would overwrite it
    property bool loaded: false
    // Notifications carried over a reload, waiting for the history they belong to
    property var carried: []
    // Ticks along for the "5m"-style ages
    property real now: Date.now()

    // "now", "12m", "3h", "2d"
    function ago(time: real): string {
        const minutes = Math.floor((now - time) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return minutes + "m";
        return minutes < 1440 ? Math.floor(minutes / 60) + "h" : Math.floor(minutes / 1440) + "d";
    }

    // How long a banner stays up, in ms; 0 keeps it until it's dealt with
    function popupTimeout(entry: var): int {
        const n = entry.notification;
        // The app's own timeout, already in ms
        if (n && n.expireTimeout > 0)
            return n.expireTimeout;
        if (entry.urgency === NotificationUrgency.Critical)
            return 0;
        return entry.urgency === NotificationUrgency.Low ? 4000 : 6000;
    }

    function copy(entry: var, n: Notification) {
        entry.appName = n.appName;
        entry.appIcon = n.appIcon;
        // Raw image data lives with the notification, so only paths survive it
        entry.image = n.image.startsWith("image://qsimage") ? "" : n.image;
        entry.summary = n.summary;
        entry.body = n.body;
        entry.urgency = n.urgency;
        entry.desktopEntry = n.desktopEntry;
    }

    function add(n: Notification) {
        n.tracked = true;
        // A reload hands over the notifications still open; they already have entries
        if (n.lastGeneration) {
            n.closed.connect(() => root.release(n));
            if (loaded)
                link([n]);
            else
                carried = [...carried, n];
            return;
        }
        // A replacement (same id, still alive) takes its predecessor's place; a fresh entry object
        // makes its delegates pick up the new notification. Ids restart with the shell, so entries
        // saved from an earlier run never match
        const previous = history.find(e => e.notification && e.id === n.id) ?? popups.find(e => e.notification && e.id === n.id);
        const entry = {
            id: n.id,
            notification: n,
            time: Date.now()
        };
        copy(entry, n);
        n.closed.connect(() => root.release(n));
        if (previous) {
            history = history.map(e => e === previous ? entry : e);
            popups = popups.filter(e => e !== previous);
        } else if (!n.transient) {
            const kept = [entry, ...history];
            for (const old of kept.slice(maxHistory))
                old.notification?.dismiss();
            history = kept.slice(0, maxHistory);
            unread = true;
        }
        if (!silenced)
            popups = [entry, ...popups].slice(0, maxPopups);
        save();
    }

    // The app closed it or it was acted on: the banner goes, the entry stays as a copy
    function release(n: Notification) {
        history = history.map(e => {
            if (e.notification !== n)
                return e;
            const kept = Object.assign({}, e, {
                notification: null
            });
            copy(kept, n);
            return kept;
        });
        popups = popups.filter(e => e.notification !== n);
        save();
    }

    function hidePopup(entry: var) {
        popups = popups.filter(e => e !== entry);
    }

    // Cleared by hand
    function remove(entry: var) {
        history = history.filter(e => e !== entry);
        popups = popups.filter(e => e !== entry);
        save();
        entry.notification?.dismiss();
    }

    function clear() {
        for (const entry of history)
            entry.notification?.dismiss();
        history = [];
        popups = [];
        save();
    }

    // A click: the notification's own action while the app still has it (that's what opens the
    // chat), else the app itself. The entry stays
    function activate(entry: var) {
        const action = entry.notification?.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        else
            follow(entry);
        hidePopup(entry);
    }

    function invoke(entry: var, action: NotificationAction) {
        action.invoke();
        hidePopup(entry);
    }

    // The app behind a notification: its desktop entry hint, else its name, matched against
    // ids and window classes and then the entries' own names ("Telegram" is
    // org.telegram.desktop). Null until the entries have loaded
    function desktopEntryFor(entry: var): var {
        const apps = DesktopEntries.applications.values;
        if (apps.length === 0)
            return null;
        const hint = entry.notification?.desktopEntry || entry.desktopEntry || "";
        const name = entry.notification?.appName || entry.appName || "";
        return (hint !== "" ? DesktopEntries.heuristicLookup(hint) : null) ?? (name !== "" ? DesktopEntries.heuristicLookup(name) : null) ?? apps.find(a => a.name.toLowerCase() === name.toLowerCase()) ?? null;
    }

    // Focuses the app's window, or starts the app when it has none
    function follow(entry: var) {
        const desktop = desktopEntryFor(entry);
        const names = [desktop?.startupClass, desktop?.id, entry.appName].filter(s => s).map(s => s.toLowerCase());
        const window = Hyprland.toplevels.values.find(t => names.includes((t.wayland?.appId || t.lastIpcObject?.class || "").toLowerCase()));
        if (window)
            Focus.run(["focuswindow address:0x" + window.address]);
        else
            desktop?.execute();
    }

    function save() {
        if (loaded)
            saveTimer.restart();
    }

    // Gives entries saved this run back their live notifications. Ids restart with the shell, so
    // only the newest entry for an id is this run's
    function link(notifications: var) {
        const linked = new Set();
        history = history.map(e => {
            const n = linked.has(e.id) || e.notification ? null : notifications.find(n => n.id === e.id);
            if (!n)
                return e;
            linked.add(e.id);
            return Object.assign({}, e, {
                notification: n
            });
        });
    }

    onSilencedChanged: {
        if (silenced)
            popups = [];
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => root.add(n)
    }

    // History on disk; notifications still alive after a reload get their entries back
    FileView {
        id: store

        path: Quickshell.statePath("notifications.json")
        // Once per run; anything that arrived while loading stays on top
        onLoaded: {
            if (root.loaded)
                return;
            const restored = (saved.entries ?? []).map(e => Object.assign({}, e, {
                        notification: null
                    }));
            root.history = [...root.history, ...restored].slice(0, root.maxHistory);
            root.link(root.carried);
            root.carried = [];
            root.loaded = true;
            root.save();
        }
        // No history yet on the first run
        onLoadFailed: {
            root.loaded = true;
        }

        JsonAdapter {
            id: saved

            property var entries: []
        }
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: {
            saved.entries = root.history.map(e => ({
                        id: e.id,
                        appName: e.appName,
                        appIcon: e.appIcon,
                        image: e.image,
                        summary: e.summary,
                        body: e.body,
                        urgency: e.urgency,
                        desktopEntry: e.desktopEntry,
                        time: e.time
                    }));
            store.writeAdapter();
        }
    }

    IpcHandler {
        target: "notifications"

        function toggleSilence(): void {
            root.silenced = !root.silenced;
        }

        function clear(): void {
            root.clear();
        }
    }
}
