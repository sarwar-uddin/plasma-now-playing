import QtQuick
import QtQuick.LocalStorage as Sql
import org.kde.plasma.private.mpris as Mpris
import "../code/scrobble.js" as S

// Watches one MPRIS player, decides when a track counts as a listen, keeps
// every listen in a local SQLite history and uploads them to ListenBrainz
// (queued while offline).
Item {
    id: sc
    visible: false

    property var player: null
    property bool listenBrainz: false
    property string token: ""
    property string apiBase: "https://api.listenbrainz.org"
    property string localOnlyPlayers: ""
    property string ignoredPlayers: ""

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string identity: hasPlayer ? (player.identity || "") : ""
    readonly property string desktopEntry: hasPlayer ? (player.desktopEntry || "") : ""
    readonly property string artist: hasPlayer ? S.norm(player.artist) : ""
    readonly property string track: hasPlayer ? S.norm(player.track) : ""
    readonly property string album: hasPlayer ? S.norm(player.album) : ""
    readonly property real lengthSec: hasPlayer ? (player.length || 0) / 1e6 : 0

    readonly property bool ignored: S.matchesAny(ignoredPlayers, identity, desktopEntry)
    readonly property bool uploads: listenBrainz && token.length > 0
                                    && !S.matchesAny(localOnlyPlayers, identity, desktopEntry)

    // ---- current session (read by the UI) --------------------------------
    property string key: ""
    property int startTs: 0
    property real played: 0
    property real need: -1          // seconds needed, -1 = never counts
    property bool scrobbled: false
    readonly property bool eligible: key !== "" && need > 0 && !ignored && artist !== ""
    readonly property real progress: eligible ? Math.min(1, played / need) : 0

    // ---- service state ---------------------------------------------------
    property int pending: 0
    property string lastError: ""
    property int revision: 0        // bumps whenever the history changes
    property bool busy: false

    property real lastTick: 0
    property real lastPos: 0

    function db() {
        const d = Sql.LocalStorage.openDatabaseSync("NowPlayingScrobbles", "", "Now Playing listen history", 20000000)
        if (d.version === "") {
            d.changeVersion("", "1", tx => {
                tx.executeSql("CREATE TABLE IF NOT EXISTS listens (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, artist TEXT NOT NULL, track TEXT NOT NULL, album TEXT, duration REAL, player TEXT, played REAL, status INTEGER NOT NULL)")
                tx.executeSql("CREATE INDEX IF NOT EXISTS listens_ts ON listens(ts)")
                tx.executeSql("CREATE INDEX IF NOT EXISTS listens_status ON listens(status)")
            })
        }
        return d
    }
    // status: 0 = queued for upload, 1 = uploaded, 2 = local only
    readonly property int queued: 0
    readonly property int sent: 1
    readonly property int localOnly: 2

    function query(sql, args) {
        let rows = []
        db().readTransaction(tx => {
            const r = tx.executeSql(sql, args || [])
            for (let i = 0; i < r.rows.length; i++) rows.push(r.rows.item(i))
        })
        return rows
    }
    function exec(sql, args) {
        db().transaction(tx => tx.executeSql(sql, args || []))
    }

    function refreshPending() {
        pending = query("SELECT COUNT(*) AS n FROM listens WHERE status = 0")[0].n
    }

    // ---- session handling ------------------------------------------------
    function evaluate() {
        const k = hasPlayer && track !== "" ? S.sessionKey(identity, artist, track, album) : ""
        if (k === key) return
        key = k
        begin()
    }
    function begin() {
        startTs = Math.floor(Date.now() / 1000)
        played = 0
        scrobbled = false
        need = S.threshold(lengthSec)
        lastTick = Date.now()
        lastPos = hasPlayer ? player.position / 1e6 : 0
        if (key !== "" && playing) nowPlaying()
    }

    onArtistChanged: Qt.callLater(evaluate)
    onTrackChanged: Qt.callLater(evaluate)
    onAlbumChanged: Qt.callLater(evaluate)
    onIdentityChanged: Qt.callLater(evaluate)
    onPlayerChanged: Qt.callLater(evaluate)
    // length often arrives after the title
    onLengthSecChanged: if (!scrobbled) need = S.threshold(lengthSec)
    onPlayingChanged: {
        lastTick = Date.now()
        if (playing && key !== "" && played < 1) nowPlaying()
    }

    Timer {
        interval: 1000; repeat: true
        running: sc.playing && sc.key !== ""
        onTriggered: sc.tick()
    }
    function tick() {
        const now = Date.now()
        // cap the step so a suspend/resume doesn't count as listening
        const dt = Math.min(2.5, Math.max(0, (now - lastTick) / 1000))
        lastTick = now
        player.updatePosition()
        const pos = player.position / 1e6
        if (S.isRestart(lastPos, pos, played)) {
            lastPos = pos
            begin()
            return
        }
        lastPos = pos
        played += dt * (player.rate > 0 ? player.rate : 1)
        if (!scrobbled && eligible && played >= need) scrobble()
    }

    function scrobble() {
        scrobbled = true
        const status = uploads ? queued : localOnly
        exec("INSERT INTO listens (ts, artist, track, album, duration, player, played, status) VALUES (?,?,?,?,?,?,?,?)",
             [startTs, artist, track, album, lengthSec, identity, Math.round(played), status])
        revision++
        refreshPending()
        if (status === queued) flush()
    }

    // ---- ListenBrainz ----------------------------------------------------
    function post(path, body, done) {
        const xhr = new XMLHttpRequest()
        xhr.open("POST", apiBase + path)
        xhr.setRequestHeader("Authorization", "Token " + token)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status, xhr.responseText)
        }
        xhr.send(JSON.stringify(body))
    }

    function nowPlaying() {
        if (!uploads || ignored || artist === "") return
        post("/1/submit-listens", S.listenPayload("playing_now", [{ artist: artist, track: track, album: album, durationSec: lengthSec, player: identity }]), () => {})
    }

    function flush() {
        if (busy || !listenBrainz || token === "") return
        const rows = query("SELECT * FROM listens WHERE status = 0 ORDER BY ts LIMIT 100")
        if (rows.length === 0) { pending = 0; return }
        busy = true
        const listens = rows.map(r => ({ ts: r.ts, artist: r.artist, track: r.track, album: r.album, durationSec: r.duration, player: r.player }))
        post("/1/submit-listens", S.listenPayload(rows.length === 1 ? "single" : "import", listens), (status, text) => {
            busy = false
            if (status === 200) {
                const ids = rows.map(r => r.id).join(",")
                exec("UPDATE listens SET status = 1 WHERE id IN (" + ids + ")")
                lastError = ""
                revision++
                refreshPending()
                if (pending > 0) Qt.callLater(flush)
            } else {
                lastError = status === 0 ? "offline" : status === 401 ? "invalid token" : "HTTP " + status
                if (status === 400) {
                    // ListenBrainz rejected the data itself; keep it locally, stop retrying
                    exec("UPDATE listens SET status = 2 WHERE id IN (" + rows.map(r => r.id).join(",") + ")")
                    console.warn("Now Playing: ListenBrainz rejected listens:", text)
                    refreshPending()
                }
            }
        })
    }

    // retry the queue every few minutes (covers offline spells)
    Timer {
        interval: 5 * 60 * 1000; repeat: true
        running: sc.pending > 0 && sc.listenBrainz && sc.token !== ""
        onTriggered: sc.flush()
    }
    onTokenChanged: { lastError = ""; Qt.callLater(flush) }
    onListenBrainzChanged: Qt.callLater(flush)

    // ---- queries for the History and Stats pages ------------------------
    function recent(n) {
        return query("SELECT * FROM listens ORDER BY ts DESC LIMIT ?", [n])
    }
    function stats() {
        const now = Date.now()
        const today = S.startOfDay(now) / 1000
        const week = today - 6 * 86400
        const sum = since => query("SELECT COUNT(*) AS n, COALESCE(SUM(played),0) AS t FROM listens WHERE ts >= ?", [since])[0]
        const recentTs = query("SELECT ts FROM listens WHERE ts >= ?", [today - 400 * 86400]).map(r => r.ts)
        return {
            today: sum(today),
            week: sum(week),
            all: sum(0),
            streak: S.streak(recentTs, now),
            days: S.dailyCounts(recentTs, now, 14),
            artists: query("SELECT artist AS name, COUNT(*) AS n FROM listens WHERE ts >= ? GROUP BY artist ORDER BY n DESC, MAX(ts) DESC LIMIT 5", [week]),
            tracks: query("SELECT track AS name, artist, COUNT(*) AS n FROM listens WHERE ts >= ? GROUP BY track, artist ORDER BY n DESC, MAX(ts) DESC LIMIT 5", [week])
        }
    }
    Component.onCompleted: {
        refreshPending()
        evaluate()
        Qt.callLater(flush)
    }
}
