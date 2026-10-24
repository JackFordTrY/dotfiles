import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config

// An icon the way apps hand them over in tray menus and items ("image://icon/name"). A name the
// theme lacks falls back to its non-symbolic name, then to Breeze's spelling of it, and leaves
// `resolved` empty rather than drawing the missing-icon checkerboard. Symbolic icons are drawn for
// light themes, so they are repainted in `color`.
Image {
    id: root

    property string icon
    property color color: Theme.text2

    // GNOME names that Breeze spells differently
    readonly property var aliases: ({
            "bluetooth": "network-bluetooth",
            "bluetooth-active": "network-bluetooth-activated",
            "bluetooth-disabled": "network-bluetooth",
            "bluetooth-disconnected": "network-bluetooth",
            "application-x-addon": "plugins",
            "gnome-power-manager": "battery",
            "modem": "network-modem"
        })
    readonly property bool symbolic: icon.includes("-symbolic")
    readonly property string resolved: {
        if (!icon.startsWith("image://icon/"))
            return icon;
        const name = icon.slice("image://icon/".length).split("?")[0];
        const plain = name.replace(/-symbolic$/, "");
        for (const candidate of [name, plain, aliases[plain] ?? ""]) {
            const path = candidate === "" ? "" : Quickshell.iconPath(candidate, true);
            if (path !== "")
                return path;
        }
        return "";
    }

    source: resolved

    layer.enabled: symbolic && resolved !== ""
    layer.effect: MultiEffect {
        brightness: 1
        colorization: 1
        colorizationColor: root.color
    }
}
