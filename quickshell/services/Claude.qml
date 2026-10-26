pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Claude Code sessions and what each is doing, as the hook scripts/claude-status.sh reports it
// (`qs ipc call claude update ...`): working, waiting on you (a permission or a question), done,
// or idle once you've looked at its window since it finished. Kept across restarts; a session
// whose claude process has gone drops out, checked every minute.
Singleton {
    id: root

    // { id, project, cwd, state, pid, detail, since }, by project
    property var sessions: []
    // Saving waits for the saved list to load, or it would overwrite it
    property bool loaded: false

    // The window a project's session is in: a VS Code window titled "file - project - Visual
    // Studio Code", else any window with the project in its title (a terminal)
    function windowFor(project: string): var {
        const windows = Hyprland.toplevels.values;
        return windows.find(t => (" - " + t.title).includes(" - " + project + " - ")) ?? windows.find(t => t.title.includes(project)) ?? null;
    }

    function looking(project: string): bool {
        const active = Hyprland.activeToplevel;
        return active !== null && active === windowFor(project);
    }

    function update(id: string, state: string, cwd: string, pid: int, detail: string) {
        if (state === "ended") {
            forget(id);
            return;
        }
        const old = sessions.find(s => s.id === id);
        const project = cwd.split("/").filter(part => part !== "").pop() ?? cwd;
        // Finished while you're looking at it
        if (state === "done" && looking(project))
            state = "idle";
        const session = {
            id: id,
            project: project,
            cwd: cwd,
            state: state,
            pid: pid,
            detail: detail,
            since: old?.state === state ? old.since : Date.now()
        };
        sessions = [...sessions.filter(s => s.id !== id), session].sort((a, b) => a.project.localeCompare(b.project) || a.id.localeCompare(b.id));
        save();
    }

    function forget(id: string) {
        sessions = sessions.filter(s => s.id !== id);
        save();
    }

    // Goes to the session's window, which also counts as having seen it
    function focus(session: var) {
        const window = windowFor(session.project);
        if (window)
            Focus.run(["focuswindow address:0x" + window.address]);
    }

    // Done sessions whose window has the focus become idle
    function markSeen() {
        if (!sessions.some(s => s.state === "done" && looking(s.project)))
            return;
        sessions = sessions.map(s => s.state === "done" && looking(s.project) ? Object.assign({}, s, {
                state: "idle",
                since: Date.now()
            }) : s);
        save();
    }

    function save() {
        if (!loaded)
            return;
        saved.sessions = sessions;
        store.writeAdapter();
    }

    function checkAlive() {
        const pids = sessions.map(s => s.pid).filter(pid => pid > 1);
        if (pids.length > 0 && !alive.running) {
            alive.command = ["ps", "-o", "pid=", "-p", pids.join(",")];
            alive.running = true;
        }
    }

    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            root.markSeen();
        }
    }

    Timer {
        interval: 60000
        running: root.sessions.length > 0
        repeat: true
        onTriggered: root.checkAlive()
    }

    Process {
        id: alive

        stdout: StdioCollector {
            onStreamFinished: {
                const living = text.split("\n").map(line => Number(line.trim())).filter(pid => pid > 0);
                const gone = root.sessions.filter(s => s.pid > 1 && !living.includes(s.pid));
                if (gone.length === 0)
                    return;
                root.sessions = root.sessions.filter(s => !gone.includes(s));
                root.save();
            }
        }
    }

    FileView {
        id: store

        path: Quickshell.statePath("claude-sessions.json")
        onLoaded: {
            if (root.loaded)
                return;
            root.sessions = [...root.sessions, ...saved.sessions.filter(s => !root.sessions.some(t => t.id === s.id))];
            root.loaded = true;
            root.save();
            root.checkAlive();
        }
        // Nothing saved yet on the first run
        onLoadFailed: root.loaded = true

        JsonAdapter {
            id: saved

            property var sessions: []
        }
    }

    IpcHandler {
        target: "claude"

        function update(session: string, state: string, cwd: string, pid: int, detail: string): void {
            root.update(session, state, cwd, pid, detail);
        }

        function forget(session: string): void {
            root.forget(session);
        }
    }
}
