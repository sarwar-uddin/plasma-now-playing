import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/scrobble.js" as S

// Totals, a 14-day bar chart in the System Strip / meteogram style, and the
// week's top artists and tracks.
Item {
    id: page
    property var scrobbler
    property bool active: false
    property color crimson
    property color dim
    property var st: null

    function reload() {
        if (!active || !scrobbler) return
        st = scrobbler.stats()
        chart.requestPaint()
    }
    onActiveChanged: reload()
    Component.onCompleted: reload()
    Connections {
        target: page.scrobbler
        function onRevisionChanged() { page.reload() }
    }

    component Figure: ColumnLayout {
        property string caption
        property string value
        property string sub
        spacing: -2
        PC3.Label { text: caption; color: page.dim; font: Kirigami.Theme.smallFont }
        PC3.Label {
            text: value
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
            font.weight: Font.DemiBold
        }
        PC3.Label { text: sub; color: page.dim; font: Kirigami.Theme.smallFont; visible: sub.length > 0 }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing * 1.5

        // ---- totals -----------------------------------------------------
        GridLayout {
            Layout.alignment: Qt.AlignTop
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing * 1.5
            Figure {
                caption: i18n("Today")
                value: page.st ? page.st.today.n : "–"
                sub: page.st ? S.fmtMinutes(page.st.today.t) : ""
            }
            Figure {
                caption: i18n("7 days")
                value: page.st ? page.st.week.n : "–"
                sub: page.st ? S.fmtMinutes(page.st.week.t) : ""
            }
            Figure {
                caption: i18n("Streak")
                value: page.st ? i18np("%1 day", "%1 days", page.st.streak) : "–"
            }
            Figure {
                caption: i18n("All time")
                value: page.st ? page.st.all.n : "–"
            }
        }

        // ---- 14-day chart -----------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            spacing: 2
            PC3.Label { text: i18n("Listens per day"); color: page.dim; font: Kirigami.Theme.smallFont }
            Canvas {
                id: chart
                Layout.fillWidth: true
                Layout.fillHeight: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const days = page.st ? page.st.days : []
                    if (days.length === 0) return
                    const labelH = 14
                    const h = height - labelH, w = width
                    let max = 4
                    for (const d of days) max = Math.max(max, d.count)
                    // grid
                    ctx.strokeStyle = "#2A2A2E"
                    ctx.lineWidth = 1
                    for (let i = 0; i <= 4; i++) {
                        const y = Math.round(h * i / 4) + 0.5
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
                    }
                    const slot = w / days.length
                    const bw = Math.max(3, slot * 0.62)
                    ctx.font = "9px sans-serif"
                    ctx.textAlign = "center"
                    for (let i = 0; i < days.length; i++) {
                        const d = days[i]
                        const x = i * slot + (slot - bw) / 2
                        const bh = d.count / max * (h - 2)
                        const last = i === days.length - 1
                        if (bh > 0) {
                            const g = ctx.createLinearGradient(0, h - bh, 0, h)
                            g.addColorStop(0, last ? "#FF3355" : "#E0203F")
                            g.addColorStop(1, "#5A0C1A")
                            ctx.fillStyle = g
                            ctx.fillRect(x, h - bh, bw, bh)
                        }
                        const dt = new Date(d.day)
                        if (i % 2 === 1 || last) {
                            ctx.fillStyle = last ? "#E8E8EA" : "#7A7A82"
                            ctx.fillText(dt.getDate(), x + bw / 2, height - 2)
                        }
                    }
                    ctx.fillStyle = "#7A7A82"
                    ctx.textAlign = "left"
                    ctx.fillText(max, 2, 9)
                }
            }
        }

        // ---- top of the week -------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            spacing: 1
            PC3.Label { text: i18n("Top artists · 7 days"); color: page.dim; font: Kirigami.Theme.smallFont }
            Repeater {
                model: page.st ? page.st.artists : []
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 1.15
                    Rectangle {
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        height: 2
                        width: parent.width * modelData.n / Math.max(1, page.st.artists[0].n)
                        color: page.crimson
                        opacity: 0.7
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.bottomMargin: 3
                        PC3.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font: Kirigami.Theme.smallFont
                        }
                        PC3.Label { text: modelData.n; color: page.dim; font: Kirigami.Theme.smallFont }
                    }
                }
            }
            PC3.Label {
                visible: page.st !== null && page.st.tracks.length > 0
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                text: page.st && page.st.tracks.length ? i18n("On repeat: %1", page.st.tracks[0].name + " (" + page.st.tracks[0].n + "×)") : ""
                color: page.dim
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
        }
    }
}
