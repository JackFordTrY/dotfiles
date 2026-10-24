pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Shown after 500ms of hover, 6px above the target: centred on the pointer for wide targets,
// on the target itself for narrow ones.
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
            root.anchorX = root.target.width > 48 ? Math.round(root.pointerX) : Math.floor(root.target.width / 2);
            root.open = true;
        }
    }

    LazyLoader {
        active: root.open

        PopupWindow {
            anchor.item: root.target
            anchor.rect.x: root.anchorX - 1
            anchor.rect.y: -6
            anchor.rect.width: 2
            anchor.edges: Edges.Top
            anchor.gravity: Edges.Top
            anchor.adjustment: PopupAdjustment.SlideX
            visible: true
            color: "transparent"
            implicitWidth: box.width
            implicitHeight: box.height

            Rectangle {
                id: box

                width: Math.ceil(label.implicitWidth) + 24
                height: Math.ceil(label.implicitHeight) + 16
                radius: 10
                color: Theme.popupBackground
                border.width: 1
                border.color: Theme.purpleGlowStrong

                StyledText {
                    id: label

                    x: 12
                    y: 8
                    text: root.text
                    textFormat: root.markup ? Text.StyledText : Text.PlainText
                    color: Theme.text2
                    font.pixelSize: 13
                    lineHeight: 1.15
                }
            }
        }
    }
}
