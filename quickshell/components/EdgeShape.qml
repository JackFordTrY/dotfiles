pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.config

// The outline every tab and panel shares: a body standing on the bottom screen edge with rounded
// top corners and concave flares on both sides. Position it at x = -flare relative to the body;
// the flares spill `flare` px past each side. The path stays open along the screen edge, so the
// fill closes it there but the border doesn't run along it.
//
// A soft purple glow surrounds it. It's cut away inside the shape, so a see-through fill shows
// what's behind untinted; `glowBehind` puts it under the whole shape instead, for fills opaque
// enough to hide it (the notification banners).
Item {
    id: root

    property real bodyWidth
    property real bodyHeight
    property real radius: Theme.tabRadius
    property real flare: Theme.flare
    property color color: Theme.tabBackground
    property color borderColor: Theme.border
    property bool glowBehind: false

    // Corners can't outgrow the body while it animates
    readonly property real r: Math.max(0, Math.min(radius, bodyWidth / 2, bodyHeight - flare))
    readonly property real rightX: flare + bodyWidth
    // Room around the shape for the glow to spread into
    readonly property real glowRoom: 24

    width: bodyWidth + flare * 2
    height: bodyHeight

    // The shadow of a solid copy, with the copy and the shadow under it masked away by the same
    // outline, leaving only the halo outside
    Item {
        id: glow

        visible: !root.glowBehind
        x: -root.glowRoom
        y: -root.glowRoom
        width: root.width + root.glowRoom * 2
        height: root.height + root.glowRoom * 2

        layer.enabled: visible
        layer.effect: MultiEffect {
            // The item has the room already, so the mask lines up with it
            autoPaddingEnabled: false
            shadowEnabled: true
            shadowColor: Theme.purple0
            // As strong as the glow used to be from under a 72% fill
            shadowOpacity: 0.33
            shadowBlur: 0.8
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            maskEnabled: true
            maskInverted: true
            maskSource: glowMask
        }

        Outline {
            x: root.glowRoom
            y: root.glowRoom
            fillColor: Theme.purple0
        }
    }

    Item {
        id: glowMask

        visible: false
        x: glow.x
        y: glow.y
        width: glow.width
        height: glow.height
        layer.enabled: glow.visible

        Outline {
            x: root.glowRoom
            y: root.glowRoom
            fillColor: "black"
        }
    }

    Outline {
        fillColor: root.color
        strokeColor: root.borderColor
        strokeWidth: 1

        layer.enabled: root.glowBehind
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.purple0
            shadowOpacity: 0.45
            shadowBlur: 0.8
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    component Outline: Shape {
        property alias fillColor: path.fillColor
        property alias strokeColor: path.strokeColor
        property alias strokeWidth: path.strokeWidth

        width: root.width
        height: root.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: path

            strokeColor: "transparent"
            startX: 0
            startY: root.bodyHeight

            PathArc {
                x: root.flare
                y: root.bodyHeight - root.flare
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root.flare
                y: root.r
            }
            PathArc {
                x: root.flare + root.r
                y: 0
                radiusX: root.r
                radiusY: root.r
            }
            PathLine {
                x: root.rightX - root.r
                y: 0
            }
            PathArc {
                x: root.rightX
                y: root.r
                radiusX: root.r
                radiusY: root.r
            }
            PathLine {
                x: root.rightX
                y: root.bodyHeight - root.flare
            }
            PathArc {
                x: root.rightX + root.flare
                y: root.bodyHeight
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Counterclockwise
            }
        }
    }
}
