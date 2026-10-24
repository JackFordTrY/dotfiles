import QtQuick
import qs.config
import qs.components
import qs.services

// Notifications: hovering opens their history in the controls panel; a click silences them,
// turning the bell red and crossed out. Lit while there's something unread.
TabItem {
    icon: Notifs.silenced ? "notifications_off" : Notifs.unread ? "notifications_unread" : "notifications"
    iconColor: Notifs.silenced ? Theme.red : Notifs.unread ? Theme.accent : Theme.text2
    accentColor: Notifs.silenced ? Theme.red : Theme.accent
    onClicked: button => {
        if (button === Qt.LeftButton)
            Notifs.silenced = !Notifs.silenced;
    }
}
