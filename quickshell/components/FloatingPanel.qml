import QtQuick
import QtQuick.Effects
import qs.config

// A panel that floats free of the screen edge (the app launcher): a rounded rectangle with the
// tabs' fill, border and glow. As in EdgeShape, the glow is cut away under the panel, so the
// see-through fill shows what's behind untinted.
Item {
    id: root

    property real radius: Theme.tabRadius + 6
    property color color: Theme.tabBackground
    property color borderColor: Theme.border
    // Room around the panel for the glow to spread into
    readonly property real glowRoom: 24

    // The shadow of a solid copy, with the copy and the shadow under it masked away
    Item {
        id: glow

        x: -root.glowRoom
        y: -root.glowRoom
        width: root.width + root.glowRoom * 2
        height: root.height + root.glowRoom * 2

        layer.enabled: true
        layer.effect: MultiEffect {
            // The item has the room already, so the mask lines up with it
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: Theme.purple0
            shadowOpacity: 0.33
            shadowBlur: 0.8
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            maskEnabled: true
            maskInverted: true
            maskSource: glowMask
        }

        Rectangle {
            x: root.glowRoom
            y: root.glowRoom
            width: root.width
            height: root.height
            radius: root.radius
            color: Theme.purple0
        }
    }

    Item {
        id: glowMask

        visible: false
        x: glow.x
        y: glow.y
        width: glow.width
        height: glow.height
        layer.enabled: true

        Rectangle {
            x: root.glowRoom
            y: root.glowRoom
            width: root.width
            height: root.height
            radius: root.radius
            color: "black"
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: 1
        border.color: root.borderColor
    }
}
