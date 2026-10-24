pragma Singleton

import QtQuick
import Quickshell

// Purple Night palette (as in hypr/_variables.conf) and the bar's geometry. Everything the shell
// draws grows out of the bottom screen edge: a flat bottom, rounded top corners and concave
// flares where the shape meets the edge.
Singleton {
    // Purple Night
    readonly property color surface0: "#0d0b14"
    readonly property color surface1: "#100f1a"
    readonly property color surface2: "#141225"
    readonly property color surface3: "#1b1733"
    readonly property color surface4: "#221d3d"
    readonly property color surface5: "#2b2550"
    readonly property color text1: "#e6e1ff"
    readonly property color text2: "#b9b4d6"
    readonly property color textMuted: "#8f8aa8"
    readonly property color textDim: "#6f6a8d"
    readonly property color purple0: "#6c63ff"
    readonly property color purple2: "#a599ff"
    readonly property color pink: "#ff79c6"
    readonly property color cyan: "#7afcff"
    readonly property color blue: "#4da6ff"
    readonly property color green: "#4dffb5"
    readonly property color red: "#ff5555"
    readonly property color purpleGlow: Qt.rgba(108 / 255, 99 / 255, 1, 0.18)
    readonly property color purpleGlowStrong: Qt.rgba(108 / 255, 99 / 255, 1, 0.32)

    readonly property color barBackground: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.55)
    // Tabs and panels, over Hyprland's blur of what's behind them (see the quickshell layer rules in
    // hypr/_rules.conf). Keep it above their ignore_alpha (0.3), or the blur drops out
    readonly property color tabBackground: Qt.alpha(surface3, 0.35)
    // Notification banners, blurred behind. Keep it above their layer rule's ignore_alpha (0.4),
    // or the blur drops out
    readonly property color notificationBackground: Qt.alpha(surface3, 0.72)
    readonly property color border: purpleGlow
    readonly property color hover: Qt.alpha(surface4, 0.8)
    readonly property color active: Qt.alpha(surface5, 0.85)
    // Tiles, chips and fields inside panels
    readonly property color raised: Qt.alpha(surface2, 0.6)
    // Tray menus and tooltips
    readonly property color popupBackground: Qt.alpha(surface1, 0.8)
    readonly property color accent: purple2

    // The exclusive zone; tabs stand 36px tall inside it
    readonly property int barHeight: 44
    readonly property int tabHeight: 36
    readonly property int tabRadius: 14
    // Radius of the concave corners where a shape meets the screen edge
    readonly property int flare: 8
    // Gap between neighbouring tabs, leaving room for both flares
    readonly property int tabGap: flare * 2 + 6
    readonly property int edgePadding: 12

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string iconFont: "Material Symbols Sharp"
    readonly property int fontSize: 15
    readonly property int iconSize: 20
    readonly property int iconWeight: 300

    readonly property int duration: 300
    // Panels open after this dwell, so sweeping across the bar doesn't pop them
    readonly property int hoverDelay: 50
    readonly property int openDuration: 240
    readonly property int closeDuration: 160
    // Material 3 "emphasized decelerate" and "emphasized accelerate"
    readonly property list<real> emphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]

    function mix(from: color, to: color, t: real): color {
        return Qt.rgba(from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t, from.b + (to.b - from.b) * t, from.a + (to.a - from.a) * t);
    }
}
