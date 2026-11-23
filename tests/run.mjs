// node tests/run.mjs — unit tests for package/contents/code/scrobble.js
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const src = readFileSync(new URL("../package/contents/code/scrobble.js", import.meta.url), "utf8")
    .replace(/^\.pragma.*$/m, "")
const names = [...src.matchAll(/^function (\w+)/gm)].map(m => m[1])
const S = new Function(src + "\nreturn {" + names.join(",") + ", CLIENT, CLIENT_VERSION}")()

let n = 0
const t = (name, fn) => { fn(); n++ }

t("threshold", () => {
    assert.equal(S.threshold(20), -1)
    assert.equal(S.threshold(30), 15)
    assert.equal(S.threshold(200), 100)
    assert.equal(S.threshold(600), 240)
    assert.equal(S.threshold(0), 240)
})
t("matchesAny", () => {
    assert.ok(S.matchesAny("strawberry", "Strawberry", "org.strawberrymusicplayer.strawberry"))
    assert.ok(S.matchesAny(" firefox , chromium", "Mozilla Firefox", ""))
    assert.ok(!S.matchesAny("", "Strawberry", ""))
    assert.ok(!S.matchesAny("spotify", "Strawberry", ""))
    assert.ok(!S.matchesAny(" , ", "x", ""))
})
t("isRestart", () => {
    assert.ok(S.isRestart(180, 1, 180))
    assert.ok(!S.isRestart(180, 1, 10))      // barely played: not a new listen
    assert.ok(!S.isRestart(60, 50, 60))      // small seek back
    assert.ok(!S.isRestart(20, 2, 40))       // jump of < 20 s
})
t("sessionKey trims", () => {
    assert.equal(S.sessionKey("a", " b ", "c", undefined), S.sessionKey("a", "b", "c", ""))
    assert.notEqual(S.sessionKey("a", "b", "c", "d"), S.sessionKey("a", "b", "c", "e"))
})
t("listenPayload", () => {
    const l = { ts: 1795400000, artist: "Arnob", track: "Hok Kolorob", album: "", durationSec: 241.5, player: "Strawberry" }
    const single = S.listenPayload("single", [l])
    assert.equal(single.listen_type, "single")
    assert.equal(single.payload[0].listened_at, 1795400000)
    const md = single.payload[0].track_metadata
    assert.equal(md.artist_name, "Arnob")
    assert.equal(md.track_name, "Hok Kolorob")
    assert.ok(!("release_name" in md))
    assert.equal(md.additional_info.duration_ms, 241500)
    assert.equal(md.additional_info.media_player, "Strawberry")
    assert.equal(md.additional_info.submission_client, S.CLIENT)
    const now = S.listenPayload("playing_now", [{ ...l, album: "Rodeo" }])
    assert.ok(!("listened_at" in now.payload[0]))
    assert.equal(now.payload[0].track_metadata.release_name, "Rodeo")
    const noLen = S.listenPayload("single", [{ ...l, durationSec: 0 }])
    assert.ok(!("duration_ms" in noLen.payload[0].track_metadata.additional_info))
})
t("dailyCounts", () => {
    const now = new Date(2026, 10, 23, 15, 0).getTime()
    const at = (d, h) => new Date(2026, 10, d, h).getTime() / 1000
    const days = S.dailyCounts([at(23, 1), at(23, 14), at(22, 23), at(10, 12), at(9, 12)], now, 14)
    assert.equal(days.length, 14)
    assert.equal(days[13].count, 2)
    assert.equal(days[12].count, 1)
    assert.equal(days[0].day, new Date(2026, 10, 10).getTime())
    assert.equal(days[0].count, 1)                         // the 9th is out of range
    assert.equal(days.reduce((a, d) => a + d.count, 0), 4)
})
t("streak", () => {
    const now = new Date(2026, 10, 23, 9, 0).getTime()
    const at = d => new Date(2026, 10, d, 20).getTime() / 1000
    assert.equal(S.streak([at(22), at(21), at(20), at(18)], now), 3)   // nothing yet today
    assert.equal(S.streak([new Date(2026, 10, 23, 8).getTime() / 1000, at(22)], now), 2)
    assert.equal(S.streak([at(20)], now), 0)
    assert.equal(S.streak([], now), 0)
})
t("fmtMinutes", () => {
    assert.equal(S.fmtMinutes(0), "0 min")
    assert.equal(S.fmtMinutes(59 * 60), "59 min")
    assert.equal(S.fmtMinutes(125 * 60), "2 h 05 m")
})
console.log(`ok — ${n} tests`)
