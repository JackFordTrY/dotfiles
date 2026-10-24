pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A GtkLabel's text: a row of BarText runs, switching to Font Awesome for glyphs the Nerd Font
// lacks (the same fallback Pango does).
Row {
    id: root

    property string text
    property real size: 16
    property bool bold: false
    property color color: Theme.text1
    property real baselineY: Theme.pillBaseline

    height: parent ? parent.height : Theme.barHeight

    Repeater {
        model: Theme.segments(root.text)

        BarText {
            required property var modelData

            text: modelData.text
            fa: modelData.fa
            size: root.size
            bold: root.bold
            color: root.color
            baselineY: root.baselineY
        }
    }
}
