#!/bin/sh
# A Claude Code hook that tells the shell what each session is doing, for the Claude chips in the
# bar (services/Claude.qml). ~/.claude/settings.json runs it on SessionStart, UserPromptSubmit,
# PostToolUse, Notification, Stop and SessionEnd, with the event as JSON on stdin. It never
# blocks or fails Claude: anything that goes wrong leaves the chip as it was.

eval "$(jq -r '@sh "event=\(.hook_event_name // "") kind=\(.notification_type // "") session=\(.session_id // "") cwd=\(.cwd // "") message=\(.message // "")"' 2>/dev/null)" || exit 0
session=$(printf '%s' "$session" | tr -cd 'A-Za-z0-9_-')
[ -n "$session" ] || exit 0
# The folder the session was started in; cwd follows Claude's cd's
cwd="${CLAUDE_PROJECT_DIR:-$cwd}"

case "$event" in
SessionStart) state=idle ;;
UserPromptSubmit | PostToolUse) state=working ;;
Stop) state=done ;;
SessionEnd) state=ended ;;
Notification)
    # Waiting on you: a permission, or a question (which comes as a permission for
    # AskUserQuestion); the idle reminder changes nothing
    case "$kind" in
    permission_prompt | elicitation_dialog) state=waiting ;;
    *) exit 0 ;;
    esac
    ;;
*) exit 0 ;;
esac

# Most tool calls change nothing, so the state last sent is kept to skip those
cache="${XDG_RUNTIME_DIR:-/tmp}/claude-status"
mkdir -p "$cache"
if [ "$state" = ended ]; then
    rm -f "$cache/$session"
else
    [ "$(cat "$cache/$session" 2>/dev/null)" = "$state" ] && exit 0
    printf '%s' "$state" >"$cache/$session"
fi

# The claude process, so the shell can drop a session that went away without saying so
pid=$PPID
while [ "$pid" -gt 1 ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" != claude ]; do
    pid=$(awk '{ print $4 }' "/proc/$pid/stat" 2>/dev/null || echo 1)
done

qs ipc call claude update "$session" "$state" "$cwd" "$pid" "$message" >/dev/null 2>&1
exit 0
