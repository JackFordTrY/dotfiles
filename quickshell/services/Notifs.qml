pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon. Every notification goes into `history` (newest first, saved across
// restarts, kept for `historyLifetime` or until cleared from the panel) and, unless `silenced`,
// into `popups` for the banners that drop from the top edge. Entries are plain objects copying a notification's text
// so they outlive it; `notification` stays set while the app's notification is alive, for its
// actions. Bindings that should follow a replaced notification read through `notification`
// rather than the copies.
//
// A silence can have an end (`silenceUntil`, from the bell's menu), when banners come back on
// their own. Banners also pause while the screen is shared, so private messages don't show up on
// a call. `qs ipc call notifications toggleSilence` and `... clear` are there for keybindings.
Singleton {
    id: root

    property bool silenced: false
    // When the silence ends by itself (ms since the epoch), or 0 for when it's turned back on
    property real silencedUntil: 0
    // No banners: silenced, or the screen is being shared
    readonly property bool paused: silenced || Privacy.screenShared
    // Set by new arrivals, cleared once the history has been looked at
    property bool unread: false
    property var history: []
    property var popups: []
    // Only a safety cap; past it the oldest entries go
    readonly property int maxHistory: 200
    readonly property int maxPopups: 3
    // How long an entry stays in the history, in ms; one still on a banner waits for it to go
    readonly property int historyLifetime: 5 * 60 * 1000
    // Claude Code's sounds are played here rather than by the extension, which only shows the
    // banners: at volumes of their own, and only along with a banner. 1 is full volume. Finished
    // (or idle at the prompt):
    readonly property real claudeFinishVolume: 0.45
    // Waiting on you: a permission, or a question (which comes as a permission for AskUserQuestion)
    readonly property real claudeWaitingVolume: 0.6
    // When the next entry is due to leave (ms since the epoch), or 0 for none
    readonly property real nextExpiry: {
        const times = history.filter(e => !popups.includes(e)).map(e => e.time);
        return times.length > 0 ? Math.min(...times) + historyLifetime : 0;
    }
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
        if (!paused) {
            // A burst from one conversation shares a banner: the newest shows, counting the ones
            // that came before it while it was up
            const same = previous ? null : popups.find(e => burstKey(e) === burstKey(entry));
            entry.burst = previous?.burst ?? (same ? (same.burst ?? 1) + 1 : 1);
            popups = [entry, ...popups.filter(e => e !== same)].slice(0, maxPopups);
            if (claudeProject(entry) !== null)
                playClaudeSound(entry);
        }
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

    // What makes notifications one conversation: the app, the title (a chat, a sender, a Claude
    // project) and how urgent
    function burstKey(entry: var): string {
        const n = entry.notification;
        return [appOf(entry), n ? n.summary : entry.summary, n ? n.urgency : entry.urgency].join("\n");
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

    // Claude Code's banners come from the Claude Code Notifier extension in VS Code, which posts
    // them with plain notify-send (so under its name), titled "Claude Code — project". The
    // project ("" without one), or null for any other notification
    function claudeProject(entry: var): var {
        const n = entry.notification;
        if ((n ? n.appName : entry.appName) !== "notify-send")
            return null;
        const match = (n ? n.summary : entry.summary ?? "").match(/^Claude Code(?: — (.+))?$/);
        return match ? match[1] ?? "" : null;
    }

    // Claude finished ("Claude finished and is waiting for you") or idles at the prompt ("Claude
    // is waiting for your input")
    function claudeFinished(entry: var): bool {
        return claudeProject(entry) !== null && /waiting for you/.test(entry.body ?? "");
    }

    // The finish sound, or the two-tone chime when Claude is waiting on you
    function playClaudeSound(entry: var) {
        const finished = claudeFinished(entry);
        const volume = finished ? claudeFinishVolume : claudeWaitingVolume;
        Quickshell.execDetached(["paplay", "--volume=" + Math.round(65536 * volume), "/usr/share/sounds/freedesktop/stereo/" + (finished ? "complete" : "message") + ".oga"]);
    }

    // The app's name as shown
    function appNameOf(entry: var): string {
        if (claudeProject(entry) !== null)
            return "Claude Code";
        return (entry.notification ? entry.notification.appName : entry.appName) ?? "";
    }

    // The app an entry is grouped under in the history
    function appOf(entry: var): string {
        return appNameOf(entry) || "Other";
    }

    // Every entry from one app
    function clearApp(app: string) {
        const gone = history.filter(e => appOf(e) === app);
        history = history.filter(e => appOf(e) !== app);
        popups = popups.filter(e => appOf(e) !== app);
        save();
        for (const entry of gone)
            entry.notification?.dismiss();
    }

    // Entries past `historyLifetime` leave, the app's notification with them
    function expire() {
        const cutoff = Date.now() - historyLifetime;
        const gone = history.filter(e => e.time <= cutoff && !popups.includes(e));
        if (gone.length === 0)
            return;
        history = history.filter(e => !gone.includes(e));
        if (history.length === 0)
            unread = false;
        save();
        for (const entry of gone)
            entry.notification?.expire();
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

    // The app behind a notification: its desktop entry hint (VS Code for Claude Code's), else its
    // name, matched against ids and window classes and then the entries' own names ("Telegram"
    // is org.telegram.desktop). Null until the entries have loaded
    function desktopEntryFor(entry: var): var {
        const apps = DesktopEntries.applications.values;
        if (apps.length === 0)
            return null;
        const hint = claudeProject(entry) !== null ? "com.microsoft.VSCode" : entry.notification?.desktopEntry || entry.desktopEntry || "";
        const name = entry.notification?.appName || entry.appName || "";
        return (hint !== "" ? DesktopEntries.heuristicLookup(hint) : null) ?? (name !== "" ? DesktopEntries.heuristicLookup(name) : null) ?? apps.find(a => a.name.toLowerCase() === name.toLowerCase()) ?? null;
    }

    // Focuses the app's window, or starts the app when it has none. Claude Code's go to the
    // window with the project open, as the bar's Claude chips do
    function follow(entry: var) {
        const desktop = desktopEntryFor(entry);
        const names = [desktop?.startupClass, desktop?.id, entry.appName].filter(s => s).map(s => s.toLowerCase());
        const windows = Hyprland.toplevels.values.filter(t => names.includes((t.wayland?.appId || t.lastIpcObject?.class || "").toLowerCase()));
        const project = claudeProject(entry);
        const window = (project ? Claude.windowFor(project) : null) ?? windows[0];
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

    // Silences until `until` (ms since the epoch), or until turned back on for 0
    function silenceUntil(until: real) {
        silencedUntil = until;
        silenced = true;
    }

    onSilencedChanged: {
        if (!silenced)
            silencedUntil = 0;
    }
    onPausedChanged: {
        if (paused)
            popups = [];
    }
    // An entry held by its banner may be due already
    onPopupsChanged: expire()

    // Timers can fire a little before Date.now() says the entry is due, which would leave it and
    // stop; so this one waits a second longer, and the 30-second ticker below sweeps up as well
    Timer {
        running: root.nextExpiry > 0
        interval: Math.max(0, root.nextExpiry - Date.now()) + 1000
        onTriggered: root.expire()
    }

    Timer {
        running: root.silenced && root.silencedUntil > 0
        interval: Math.max(1000, root.silencedUntil - Date.now())
        onTriggered: root.silenced = false
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now();
            root.expire();
        }
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
