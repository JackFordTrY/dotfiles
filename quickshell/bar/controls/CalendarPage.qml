pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Today's weather over a month at a glance: today in the accent, the neighbouring months' days
// dimmed, weeks starting on the locale's first day. The arrows or the wheel page through the
// months; it's back on this month (and the weather fetched again if it's old) whenever the panel
// opens on it.
Item {
    id: root

    // The panel is open on this page
    property bool active
    readonly property date today: clock.date
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property int firstDay: Qt.locale().firstDayOfWeek
    readonly property bool thisMonth: month === today.getMonth() && year === today.getFullYear()
    // Six weeks from the one holding the 1st
    readonly property var days: {
        const offset = (new Date(year, month, 1).getDay() - firstDay + 7) % 7;
        return Array.from({
            length: 42
        }, (_, i) => new Date(year, month, 1 - offset + i));
    }

    function step(by: int) {
        const first = new Date(year, month + by, 1);
        month = first.getMonth();
        year = first.getFullYear();
    }

    function backToToday() {
        month = today.getMonth();
        year = today.getFullYear();
    }

    onActiveChanged: {
        if (!active)
            return;
        backToToday();
        Weather.refresh();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    WheelHandler {
        onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }

    // Now, then today's range
    Item {
        id: weather

        width: parent.width
        height: 28

        Row {
            visible: Weather.available
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.icon
                fill: 1
                color: Theme.accent
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.temperature + "°"
                font.pixelSize: 15
                font.bold: true
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width - range.width - 90)
                text: Weather.description + (Weather.area === "" ? "" : " · " + Weather.area)
                color: Theme.text2
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        StyledText {
            id: range

            visible: Weather.available
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "↑ " + Weather.high + "°  ↓ " + Weather.low + "°  feels " + Weather.feelsLike + "°"
            color: Theme.textMuted
            font.pixelSize: 12
        }

        StyledText {
            visible: !Weather.available
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.failed ? "Weather unavailable" : "Fetching the weather…"
            color: Theme.textDim
            font.pixelSize: 12
        }
    }

    Item {
        id: header

        anchors.top: weather.bottom
        anchors.topMargin: 8
        width: parent.width
        height: 28

        SectionLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().standaloneMonthName(root.month, Locale.LongFormat).toUpperCase() + " " + root.year
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Chip {
                visible: !root.thisMonth
                anchors.verticalCenter: parent.verticalCenter
                icon: "today"
                text: "Today"
                onClicked: root.backToToday()
            }

            Arrow {
                icon: "chevron_left"
                onClicked: root.step(-1)
            }

            Arrow {
                icon: "chevron_right"
                onClicked: root.step(1)
            }
        }
    }

    Row {
        id: weekdays

        anchors.top: header.bottom
        anchors.topMargin: 8

        Repeater {
            model: 7

            StyledText {
                required property int index

                width: root.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2).toUpperCase()
                color: Theme.textMuted
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
            }
        }
    }

    Grid {
        anchors.top: weekdays.bottom
        anchors.topMargin: 6
        columns: 7

        Repeater {
            model: root.days

            Item {
                id: cell

                required property date modelData
                readonly property bool inMonth: modelData.getMonth() === root.month
                readonly property bool isToday: modelData.toDateString() === root.today.toDateString()

                width: root.width / 7
                height: 25

                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: 12
                    color: cell.isToday ? Theme.accent : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: cell.modelData.getDate()
                    color: cell.isToday ? Theme.surface0 : cell.inMonth ? Theme.text2 : Theme.textDim
                    font.pixelSize: 13
                    font.bold: cell.isToday
                }
            }
        }
    }

    component Arrow: Rectangle {
        id: arrow

        property string icon

        signal clicked

        width: 28
        height: 28
        radius: 8
        color: arrowArea.containsMouse ? Theme.hover : "transparent"

        MaterialIcon {
            anchors.centerIn: parent
            text: arrow.icon
            color: arrowArea.containsMouse ? Theme.text1 : Theme.text2
        }

        MouseArea {
            id: arrowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }
}
