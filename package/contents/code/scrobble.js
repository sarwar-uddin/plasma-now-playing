.pragma library
// Pure scrobbling logic: rules, player matching, ListenBrainz payloads and
// stats bucketing. No QML types here, so tests/run.mjs can load it in node.

var CLIENT = "Now Playing (Plasma)"
var CLIENT_VERSION = "2.0.0"

// Seconds of real playback needed before a track counts as a listen.
// Same rule Last.fm and ListenBrainz clients use: half the track or four
// minutes, whichever comes first; tracks under 30 s never count. With an
// unknown length (streams) we wait the full four minutes.
function threshold(lengthSec) {
    if (lengthSec > 0) {
        if (lengthSec < 30) return -1
        return Math.min(240, lengthSec / 2)
    }
    return 240
}

function norm(s) {
    return String(s || "").trim()
}

function sessionKey(player, artist, track, album) {
    return [player, artist, track, album].map(norm).join("␟")
}

// "strawberry, Firefox" -> does identity or desktop entry contain any item?
function matchesAny(list, identity, desktopEntry) {
    const hay = (norm(identity) + " " + norm(desktopEntry)).toLowerCase()
    return String(list || "").split(",")
        .map(s => s.trim().toLowerCase())
        .filter(Boolean)
        .some(s => hay.indexOf(s) >= 0)
}

// Repeat-one and "play again" keep the same metadata, so a restart shows up
// only as the position jumping back to the start after real playback.
function isRestart(lastPosSec, posSec, playedSec) {
    return playedSec >= 30 && posSec < 10 && lastPosSec - posSec > 20
}

function trackMetadata(l) {
    const info = {
        submission_client: CLIENT,
        submission_client_version: CLIENT_VERSION
    }
    if (l.player) info.media_player = l.player
    if (l.durationSec > 0) info.duration_ms = Math.round(l.durationSec * 1000)
    const md = { artist_name: l.artist, track_name: l.track, additional_info: info }
    if (norm(l.album)) md.release_name = l.album
    return md
}

// type: "single" | "import" | "playing_now"
function listenPayload(type, listens) {
    return {
        listen_type: type,
        payload: listens.map(l => {
            const o = { track_metadata: trackMetadata(l) }
            if (type !== "playing_now") o.listened_at = l.ts
            return o
        })
    }
}

function startOfDay(ms) {
    const d = new Date(ms)
    d.setHours(0, 0, 0, 0)
    return d.getTime()
}

// Listen timestamps (unix seconds) -> counts per local day, oldest first.
function dailyCounts(tsList, nowMs, days) {
    const today = startOfDay(nowMs)
    const out = []
    for (let i = days - 1; i >= 0; i--) {
        const d = new Date(today)
        d.setDate(d.getDate() - i)
        out.push({ day: d.getTime(), count: 0 })
    }
    const first = out[0].day
    for (const ts of tsList) {
        const ms = ts * 1000
        if (ms < first) continue
        const day = startOfDay(ms)
        for (let j = out.length - 1; j >= 0; j--) {
            if (out[j].day === day) { out[j].count++; break }
        }
    }
    return out
}

// Days in a row with at least one listen, ending today (or yesterday, so the
// streak doesn't read 0 every morning before the first song).
function streak(tsList, nowMs) {
    const days = {}
    for (const ts of tsList) days[startOfDay(ts * 1000)] = true
    const d = new Date(startOfDay(nowMs))
    if (!days[d.getTime()]) d.setDate(d.getDate() - 1)
    let n = 0
    while (days[d.getTime()]) { n++; d.setDate(d.getDate() - 1) }
    return n
}

function fmtMinutes(sec) {
    const m = Math.round((sec || 0) / 60)
    if (m < 60) return m + " min"
    const h = Math.floor(m / 60)
    return h + " h " + (m % 60 < 10 ? "0" : "") + (m % 60) + " m"
}
