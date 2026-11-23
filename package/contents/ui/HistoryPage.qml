import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Most recent listens, newest first. The dot on the right shows where each
// listen went: filled crimson = on ListenBrainz, crimson ring = waiting to
// upload, grey = kept on this computer only.
Item {
    id: page
    property var scrobbler
    property bool active: false
    property color crimson
    property color dim

    ListModel { id: rows }

    function reload() {
        if (!active || !scrobbler) return
        rows.clear()
        for (const r of scrobbler.recent(60)) rows.append(r)
    }
    onActiveChanged: reload()
    Connections {
        target: page.scrobbler
        function onRevisionChanged() { page.reload() }
    }

    function when(ts) {
        const d = new Date(ts * 1000)
        const today = new Date(); today.setHours(0, 0, 0, 0)
        const diff = Math.floor((today - new Date(d).setHours(0, 0, 0, 0)) / 86400000)
        const t = Qt.formatTime(d, "hh:mm")
        if (diff <= 0) return t
        if (diff === 1) return i18n("Yest %1", t)
        if (diff < 7) return Qt.formatDate(d, "ddd") + " " + t
        return Qt.formatDate(d, "d MMM")
    }

    PC3.Label {
        anchors.centerIn: parent
        visible: rows.count === 0
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: page.dim
        text: i18n("No listens yet. A track counts once you've played half of it, or four minutes.")
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: rows
        boundsBehavior: Flickable.StopAtBounds
        PC3.ScrollBar.vertical: PC3.ScrollBar {}

        delegate: Item {
            width: ListView.view.width - Kirigami.Units.gridUnit * 1.2
            height: Kirigami.Units.gridUnit * 1.35
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                PC3.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4.2
                    text: page.when(model.ts)
                    color: page.dim
                    font: Kirigami.Theme.smallFont
                }
                PC3.Label {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 3
                    text: model.track
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                PC3.Label {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    text: model.artist
                    color: page.dim
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Rectangle {
                    Layout.preferredWidth: 8; Layout.preferredHeight: 8
                    radius: 4
                    color: model.status === 1 ? page.crimson : "transparent"
                    border.width: model.status === 2 ? 0 : 1.5
                    border.color: page.crimson
                    Rectangle {
                        anchors.fill: parent; radius: 4
                        visible: model.status === 2
                        color: "#4A4A50"
                    }
                    HoverHandler { id: dotHover }
                    PC3.ToolTip.visible: dotHover.hovered
                    PC3.ToolTip.text: model.status === 1 ? i18n("On ListenBrainz")
                                    : model.status === 0 ? i18n("Waiting to upload")
                                    : i18n("Kept on this computer (%1)", model.player)
                }
            }
        }
    }
}
