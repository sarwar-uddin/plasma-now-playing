import QtQuick
import org.kde.plasma.private.mpris as Mpris
import "../package/contents/ui"
// Headless run of Scrobbler.qml against tests/mock_player.py + mock_listenbrainz.py
Item {
    Mpris.Mpris2Model { id: m }
    Scrobbler {
        id: sc
        player: m.currentPlayer
        listenBrainz: true
        token: "test-token"
        apiBase: "http://127.0.0.1:" + Qt.application.arguments[Qt.application.arguments.length - 1]
        localOnlyPlayers: "strawberry"
    }
    property int t: 0
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            t++
            console.log("t=" + t, sc.identity, "|", sc.artist, "-", sc.track, "| played", sc.played.toFixed(1), "/", sc.need,
                        "scrobbled", sc.scrobbled, "pending", sc.pending, "err", sc.lastError)
            if (t === 30) sc.flush()
            if (t === 34) {
                console.log("RECENT", JSON.stringify(sc.recent(5).map(r => [r.artist, r.track, r.status, r.played])))
                const s = sc.stats()
                console.log("STATS today", s.today.n, "streak", s.streak, "top", JSON.stringify(s.artists))
                Qt.quit()
            }
        }
    }
}
