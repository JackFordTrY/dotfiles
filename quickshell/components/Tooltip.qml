pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// GTK tooltip as Waybar shows it: after 500ms of hover, centred on the pointer (or on widgets
// narrower than 32px) 4px above the widget, styled by waybar/style.css `tooltip` plus Adwaita's
// `text-shadow: 0 1px black`.
Item {
    id: root

    required property Item target
    property string text
    property bool markup: false
    property bool hovered: false
    property real pointerX: 0

    property bool open: false
    property int anchorX: 0

    function dismiss() {
        open = false;
        delay.stop();
    }

    onHoveredChanged: hovered ? delay.restart() : dismiss()
    onTextChanged: if (text === "")
        dismiss()

    Timer {
        id: delay

        interval: 500
        onTriggered: {
            if (root.text === "")
                return;
            root.anchorX = root.target.width > 32 ? Math.round(root.pointerX) : Math.floor(root.target.width / 2);
            root.open = true;
        }
    }

    LazyLoader {
        active: root.open

        PopupWindow {
            anchor.item: root.target
            // GTK pads the anchor rect by 4px
            anchor.rect.x: root.anchorX - 1
            anchor.rect.y: -4
            anchor.rect.width: 2
            anchor.edges: Edges.Top
            anchor.gravity: Edges.Top
            anchor.adjustment: PopupAdjustment.SlideX
            visible: true
            color: "transparent"
            implicitWidth: box.width
            implicitHeight: box.height

            Item {
                anchors.fill: parent
                opacity: 0.95
                layer.enabled: true

                Rectangle {
                    id: box

                    width: Math.ceil(label.implicitWidth) + 28
                    height: label.lineCount * 20 + 28
                    radius: 16
                    color: Theme.surface1
                    border.width: 1
                    border.color: Theme.moduleBorder

                    Text {
                        x: label.x
                        y: label.y + 1
                        text: label.text
                        textFormat: label.textFormat
                        renderType: label.renderType
                        lineHeightMode: label.lineHeightMode
                        lineHeight: label.lineHeight
                        font: label.font
                        color: "black"
                    }

                    Text {
                        id: label

                        x: 14
                        // Pango line box at 11pt: 15px ascent + 5px descent, inset 14px
                        y: 14 + Theme.ascent(Theme.defaultFontSize, false) - baselineOffset
                        text: root.text
                        textFormat: root.markup ? Text.StyledText : Text.PlainText
                        renderType: Text.NativeRendering
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 20
                        color: Theme.text2
                        font.family: Theme.font
                        font.pixelSize: Math.round(Theme.defaultFontSize)
                        font.letterSpacing: Math.round(Theme.defaultFontSize * 0.6) - Math.round(Theme.defaultFontSize) * 0.6
                    }
                }
            }
        }
    }
}
