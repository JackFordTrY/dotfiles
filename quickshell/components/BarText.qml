import QtQuick
import qs.config

// One run of text rendered the way Waybar's GTK labels draw it: JetBrainsMono Nerd Font with
// Pango's hinted (whole-pixel) advances, or a Font Awesome 7 Solid glyph. The text is placed by
// its baseline so line metrics never shift it.
Text {
    id: root

    property real size: 16
    property bool fa: false
    property bool bold: false
    property real baselineY: Theme.pillBaseline
    // Pango sizes labels by glyph advances; Qt's implicitWidth also counts ink that overhangs
    // the last advance (Nerd Font icons are wider than their cell)
    readonly property real textAdvance: metrics.advanceWidth

    width: textAdvance
    y: baselineY - baselineOffset
    color: Theme.text1
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: fa ? Theme.iconFont : Theme.font
    font.weight: fa ? Font.Black : bold ? Font.Bold : Font.Normal
    // Qt only renders whole pixel sizes (GTK's 11pt, 14.67px, becomes 15px)
    font.pixelSize: Math.round(size)
    // Pango rounds the 0.6em advances to whole pixels (9.6px -> 10px at 16px); match its cell
    font.letterSpacing: fa ? 0 : Math.round(size * 0.6) - Math.round(size) * 0.6

    TextMetrics {
        id: metrics

        font: root.font
        text: root.text
    }
}
