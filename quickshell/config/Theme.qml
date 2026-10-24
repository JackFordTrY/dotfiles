pragma Singleton

import QtQuick
import Quickshell

// Purple Night palette (waybar/theme.css) and the geometry Waybar's GTK box model produces
// from waybar/style.css. Pixel values below were measured against the running Waybar.
Singleton {
    // theme.css
    readonly property color surface1: "#100f1a"
    readonly property color surface2: "#141225"
    readonly property color surface4: "#221d3d"
    readonly property color surface5: "#2b2550"
    readonly property color textPrimary: "#e6e1ff"
    readonly property color textSecondary: "#b9b4d6"
    readonly property color purple2: "#a599ff"
    readonly property color blue: "#4da6ff"
    readonly property color red: "#ff5555"
    readonly property color purpleGlow: Qt.rgba(108 / 255, 99 / 255, 1, 0.18)
    readonly property color purpleGlowStrong: Qt.rgba(108 / 255, 99 / 255, 1, 0.32)
    readonly property color infoSoft: Qt.rgba(77 / 255, 166 / 255, 1, 0.18)
    readonly property color successSoft: Qt.rgba(77 / 255, 1, 181 / 255, 0.18)
    readonly property color dangerSoft: Qt.rgba(1, 85 / 255, 85 / 255, 0.20)

    // style.css aliases
    readonly property color moduleBg: surface2
    readonly property color moduleBgAlt: surface1
    readonly property color moduleHover: surface4
    readonly property color moduleBorder: purpleGlow
    readonly property color text1: textPrimary
    readonly property color text2: textSecondary
    readonly property color barBackground: Qt.rgba(13 / 255, 11 / 255, 20 / 255, 0.45)

    // window#waybar: 46px tall (pill 26px + 10px margins), 10px side margins
    readonly property int barHeight: 46
    readonly property int barMargin: 10
    readonly property int pillTop: 10
    readonly property int pillHeight: 26

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string iconFont: "Font Awesome 7 Free"
    // GTK default font is "Adwaita Sans 11"; Waybar's `*` rule only swaps the family
    readonly property real defaultFontSize: 11 * 96 / 72

    // CSS `transition: all 0.3s ease-in-out`
    readonly property int transitionDuration: 300
    readonly property list<real> easeInOut: [0.42, 0, 0.58, 1, 1, 1]

    // Glyphs JetBrainsMono Nerd Font lacks; Pango falls back to Font Awesome 7 Free Solid for them
    readonly property var faGlyphs: ["", "", "", "", "", ""]

    // Split text into runs by the font Pango would pick for each glyph
    function segments(text: string): var {
        const runs = [];
        for (const ch of text) {
            const fa = faGlyphs.includes(ch);
            if (runs.length && runs[runs.length - 1].fa === fa)
                runs[runs.length - 1].text += ch;
            else
                runs.push({ text: ch, fa: fa });
        }
        return runs;
    }

    // Pango line metrics with hinting: FreeType rounds ascent and descent up to whole pixels
    function ascent(size: real, fa: bool): int {
        return Math.ceil(size * (fa ? 448 / 512 : 1.02));
    }
    function descent(size: real, fa: bool): int {
        return Math.ceil(size * (fa ? 64 / 512 : 0.3));
    }

    // Baseline of a GtkLabel whose content box is `height` tall at `top` (text is centred, floored)
    function baseline(top: real, height: real, size: real, nf: bool, fa: bool): int {
        const a = Math.max(nf ? ascent(size, false) : 0, fa ? ascent(size, true) : 0);
        const d = Math.max(nf ? descent(size, false) : 0, fa ? descent(size, true) : 0);
        return top + Math.floor((height - a - d) / 2) + a;
    }

    // Pill labels: content box starts below margin, 1px border and 2px top padding
    readonly property int pillBaseline: baseline(pillTop + 3, pillHeight - 4, 16, true, false)
    // Unboxed 16px labels fill the whole bar height
    readonly property int labelBaseline: baseline(0, barHeight, 16, true, false)
}
