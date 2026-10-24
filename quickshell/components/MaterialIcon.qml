import QtQuick
import QtQuick.Effects
import qs.config

// A Material Symbols Sharp icon by ligature name ("home", "wifi"...). `fill` morphs it from
// outline to solid and `glow` adds the purple halo that active and hovered icons get.
//
// The morph cross-fades a solid copy over the outline instead of animating the font's FILL axis:
// Qt builds a new font instance, mapping the whole font file again, for every axis value it sees
// and never frees them, so an animated axis grew the shell by gigabytes.
StyledText {
    id: root

    property real size: Theme.iconSize
    property real fill: 0
    property real glow: 0
    property color glowColor: Theme.purple0

    color: Theme.text2
    font.family: Theme.iconFont
    font.pixelSize: size
    font.variableAxes: ({
            FILL: 0,
            wght: Theme.iconWeight,
            GRAD: -25,
            opsz: Math.max(20, Math.min(48, root.size))
        })

    layer.enabled: glow > 0
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.glowColor
        shadowOpacity: root.glow
        shadowBlur: 0.7
        blurMax: 12
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    StyledText {
        visible: opacity > 0
        opacity: root.fill
        text: root.text
        color: root.color
        animateColor: false
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        font.variableAxes: ({
                FILL: 1,
                wght: Theme.iconWeight,
                GRAD: -25,
                opsz: Math.max(20, Math.min(48, root.size))
            })
    }

    Behavior on fill {
        NumberAnimation {
            duration: Theme.duration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on glow {
        NumberAnimation {
            duration: Theme.duration
            easing.type: Easing.OutCubic
        }
    }
}
