import QtQuick
import qs.config

Text {
    property bool animateColor: true

    color: Theme.text1
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: Theme.font
    font.pixelSize: Theme.fontSize

    Behavior on color {
        enabled: animateColor

        ColorAnimation {
            duration: Theme.duration
            easing.type: Easing.OutCubic
        }
    }
}
