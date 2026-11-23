import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../package/contents/ui"
// Offscreen render of the History and Stats pages with demo listens.
// QT_QPA_PLATFORM=offscreen qml6 tests/render.qml -- <outdir>
Rectangle {
    width: 620; height: 190
    color: "#141416"
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: "#E8E8EA"
    Scrobbler { id: sc }
    property var pages: [hist, stats]
    HistoryPage { id: hist; anchors.fill: parent; anchors.margins: 6; scrobbler: sc; crimson: "#E0203F"; dim: "#9A9AA2"; visible: false }
    StatsPage { id: stats; anchors.fill: parent; anchors.margins: 6; scrobbler: sc; crimson: "#E0203F"; dim: "#9A9AA2"; visible: false }
    function seed() {
        sc.exec("DELETE FROM listens")
        const songs = [["Arnob","Hok Kolorob"],["Shunno","Shopnochura"],["Aurthohin","Amar Prithibi"],["Arnob","Tumi Jaio Na"],
                       ["Bob Dylan","Visions of Johanna"],["Lalon (trad.)","Khachar Bhitor"],["Radiohead","Reckoner"],["Arnob","Hok Kolorob"]]
        const now = Date.now() / 1000
        let k = 0
        for (let d = 13; d >= 0; d--) {
            const n = (d * 7 + 3) % 6 + (d === 0 ? 3 : 0)
            for (let i = 0; i < n; i++) {
                const s = songs[k++ % songs.length]
                sc.exec("INSERT INTO listens (ts, artist, track, album, duration, player, played, status) VALUES (?,?,?,?,?,?,?,?)",
                        [Math.floor(now - d * 86400 - i * 900 - 600), s[0], s[1], "", 240, k % 3 ? "Strawberry" : "Firefox", 200, k % 3 ? 2 : (d === 0 && i === 0 ? 0 : 1)])
            }
        }
        sc.revision++
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            seed()
            const out = Qt.application.arguments[Qt.application.arguments.length - 1]
            hist.visible = true; hist.active = true
            Qt.callLater(() => grabToImage(r => {
                r.saveToFile(out + "/history.png")
                hist.visible = false; stats.visible = true; stats.active = true
                Qt.callLater(() => grabToImage(r2 => { r2.saveToFile(out + "/stats.png"); Qt.quit() }))
            }))
        }
    }
}
