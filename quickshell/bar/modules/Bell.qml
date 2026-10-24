import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Notifications: hovering opens their history in the controls panel; a click silences them,
// turning the bell red and crossed out. A right click offers a silence that ends by itself (an
// hour, or until 8:00), shown in the tooltip. Lit while there's something unread.
TabItem {
    id: root

    property bool menuOpen: false
    // A timed silence ends at this hour of the morning
    readonly property int morning: 8
    readonly property var options: [...(Notifs.silenced ? [
                {
                    kind: "on",
                    icon: "notifications_active",
                    text: "Notifications back on"
                }
            ] : []),
        {
            kind: "hour",
            icon: "timer",
            text: "Silence for 1 hour"
        },
        {
            kind: "morning",
            icon: "bedtime",
            text: "Silence until " + morning + ":00"
        },
        ...(Notifs.silenced && Notifs.silencedUntil === 0 ? [] : [
                {
                    kind: "always",
                    icon: "notifications_off",
                    text: "Silence until turned back on"
                }
            ])]

    // The next time it's `morning` o'clock: today's if that's still to come
    function nextMorning(): real {
        const at = new Date();
        if (at.getHours() >= morning)
            at.setDate(at.getDate() + 1);
        at.setHours(morning, 0, 0, 0);
        return at.getTime();
    }

    function choose(kind: string) {
        menuOpen = false;
        if (kind === "on")
            Notifs.silenced = false;
        else if (kind === "hour")
            Notifs.silenceUntil(Date.now() + 60 * 60 * 1000);
        else if (kind === "morning")
            Notifs.silenceUntil(nextMorning());
        else
            Notifs.silenceUntil(0);
    }

    icon: Notifs.silenced ? "notifications_off" : Notifs.unread ? "notifications_unread" : "notifications"
    iconColor: Notifs.silenced ? Theme.red : Notifs.unread ? Theme.accent : Theme.text2
    accentColor: Notifs.silenced ? Theme.red : Theme.accent
    tooltip: !Notifs.silenced ? "" : Notifs.silencedUntil > 0 ? "Silenced until " + Qt.formatTime(new Date(Notifs.silencedUntil), "hh:mm") : "Silenced"
    onClicked: button => {
        if (button === Qt.LeftButton)
            Notifs.silenced = !Notifs.silenced;
        else if (button === Qt.RightButton)
            menuOpen = true;
    }

    LazyLoader {
        active: root.menuOpen

        ContextMenu {
            anchor.item: root
            anchor.rect.x: root.width / 2
            anchor.rect.width: 1
            anchor.rect.height: 1
            anchor.edges: Edges.Top
            anchor.gravity: Edges.Top
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
            visible: true
            entries: root.options
            onChosen: index => root.choose(root.options[index].kind)
            onVisibleChanged: {
                if (!visible)
                    root.menuOpen = false;
            }
        }
    }
}
