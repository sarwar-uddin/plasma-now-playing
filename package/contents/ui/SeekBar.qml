import QtQuick

// Chart-style progress line: dark grid ticks, crimson filled track, glowing head dot.
// Click or drag to seek (when seekable).
Item {
    id: bar

    property real position: 0     // microseconds
    property real length: 0       // microseconds
    property bool seekable: false
    signal seekRequested(real target)

    readonly property real frac: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    property real dragFrac: -1
    readonly property real shownFrac: dragFrac >= 0 ? dragFrac : frac

    readonly property color grid: "#2A2A2E"
    readonly property color gridStrong: "#4A4A50"
    readonly property color crimson: "#E0203F"

    implicitHeight: 14

    // baseline
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 2
        color: bar.gridStrong
    }
    // ticks every 10%
    Repeater {
        model: 11
        Rectangle {
            required property int index
            x: Math.round(index * (bar.width - 1) / 10)
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: index % 5 === 0 ? 10 : 6
            color: index % 5 === 0 ? bar.gridStrong : bar.grid
        }
    }
    // played part
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: bar.width * bar.shownFrac; height: 3
        radius: 1.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#5A0A18" }
            GradientStop { position: 1; color: bar.crimson }
        }
    }
    // glowing head
    Rectangle {
        visible: bar.length > 0
        x: bar.width * bar.shownFrac - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 11; height: 11; radius: 5.5
        color: Qt.rgba(224 / 255, 32 / 255, 63 / 255, 0.28)
        Rectangle {
            anchors.centerIn: parent
            width: 5; height: 5; radius: 2.5
            color: bar.crimson
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -4; anchors.bottomMargin: -4
        enabled: bar.seekable && bar.length > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        function fracAt(x) { return Math.max(0, Math.min(1, x / bar.width)) }
        onPressed: mouse => bar.dragFrac = fracAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) bar.dragFrac = fracAt(mouse.x) }
        onReleased: mouse => {
            bar.seekRequested(fracAt(mouse.x) * bar.length)
            bar.dragFrac = -1
        }
        onCanceled: bar.dragFrac = -1
    }
}
