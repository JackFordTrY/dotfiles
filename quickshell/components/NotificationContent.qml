import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.services

// What a notification says: its image or app icon, the app and how long ago, the summary and
// the body (which may carry basic markup). Reads through the live notification while there is
// one, so replacements show up, and from the entry's copies after.
Item {
    id: root

    required property var entry
    property int bodyLines: 3
    // Off while a close button sits over it
    property bool showTime: true
    // How many came in a burst, the banner showing the newest
    property int count: 1
    // Caps the whole block; the body is trimmed with an ellipsis to fit
    property real maxHeight: Infinity
    // A one-line summary over a one-line body, what a typical notification takes
    readonly property real oneLineHeight: app.implicitHeight + summaryLine.height + bodyLine.height + texts.spacing * 2
    readonly property var n: entry.notification
    readonly property string appName: Notifs.appNameOf(entry)
    readonly property string summary: n ? n.summary : entry.summary ?? ""
    readonly property string body: n ? n.body : entry.body ?? ""
    readonly property string image: n ? n.image : entry.image ?? ""
    readonly property string appIcon: n ? n.appIcon : entry.appIcon ?? ""
    readonly property bool critical: (n ? n.urgency : entry.urgency) === NotificationUrgency.Critical
    // Some apps put a themed icon name in the image too; those go through the icon theme
    readonly property bool imageIsIcon: image.startsWith("image://icon/")
    // The first icon that exists: a themed image, the app's icon (a name, path or URL), Claude's
    // logo for Claude Code's (which come without one), or the icon of the app's desktop entry
    readonly property string iconSource: {
        const candidates = [];
        if (imageIsIcon)
            candidates.push(image);
        if (appIcon !== "")
            candidates.push(appIcon.startsWith("/") ? "file://" + appIcon : appIcon.includes("://") ? appIcon : "image://icon/" + appIcon);
        if (Notifs.claudeProject(entry) !== null)
            candidates.push("file://" + Quickshell.shellPath("assets/claude.svg"));
        // Reads the entry list, so this re-runs once the desktop entries have loaded
        const desktopEntry = Notifs.desktopEntryFor(entry);
        if (desktopEntry?.icon)
            candidates.push("image://icon/" + desktopEntry.icon);
        return candidates.find(c => !c.startsWith("image://icon/") || Quickshell.iconPath(c.slice("image://icon/".length), true) !== "") ?? "";
    }

    implicitHeight: Math.max(picture.height, texts.implicitHeight)

    ClippingRectangle {
        id: picture

        width: 36
        height: 36
        radius: 10
        color: Theme.surface4

        Image {
            id: photo

            visible: status === Image.Ready
            anchors.fill: parent
            source: root.imageIsIcon ? "" : root.image
            sourceSize: Qt.size(72, 72)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        ThemedIcon {
            id: themed

            visible: !photo.visible && resolved !== ""
            anchors.centerIn: parent
            width: 22
            height: 22
            sourceSize: Qt.size(22, 22)
            icon: root.iconSource
        }

        MaterialIcon {
            visible: !photo.visible && !themed.visible
            anchors.centerIn: parent
            text: "notifications"
            color: root.critical ? Theme.red : Theme.text2
        }
    }

    Column {
        id: texts

        anchors.left: picture.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        spacing: 2

        Item {
            width: parent.width
            height: app.implicitHeight

            SectionLabel {
                id: app

                width: parent.width - ago.implicitWidth - 8
                text: (root.appName + (root.count > 1 ? " · " + root.count + " new" : "")).toUpperCase()
                color: root.critical ? Theme.red : Theme.textMuted
                elide: Text.ElideRight
            }

            StyledText {
                id: ago

                visible: root.showTime
                anchors.right: parent.right
                anchors.verticalCenter: app.verticalCenter
                text: Notifs.ago(root.entry.time)
                color: Theme.textDim
                font.pixelSize: 11
            }
        }

        StyledText {
            id: summaryText

            width: parent.width
            text: root.summary
            font.pixelSize: 14
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        StyledText {
            id: bodyText

            visible: text !== ""
            width: parent.width
            // Whatever room the cap leaves, at least a line
            height: Math.min(implicitHeight, Math.max(bodyLine.height, root.maxHeight - app.height - summaryText.height - texts.spacing * 2))
            text: root.body
            textFormat: Text.StyledText
            color: Theme.text2
            font.pixelSize: 13
            wrapMode: Text.Wrap
            maximumLineCount: root.bodyLines
            elide: Text.ElideRight
        }
    }

    FontMetrics {
        id: summaryLine

        font: summaryText.font
    }

    FontMetrics {
        id: bodyLine

        font: bodyText.font
    }
}
