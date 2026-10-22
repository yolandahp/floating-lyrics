import Foundation
import LyricsCore

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok { print("  ok   \(name)") } else { failures += 1; print("  FAIL \(name) \(detail())") }
}

print("LRC parser")
do {
    let lines = parseLRC("[00:12.50] If I should stay\n[00:10.00] Intro\n[01:02.123] I would only be in your way")
    check("sorted by time", lines.map(\.text) == ["Intro", "If I should stay", "I would only be in your way"], "\(lines)")
    check("times parsed", lines.map(\.time) == [10.0, 12.5, 62.123], "\(lines.map(\.time))")
}
do {
    let lines = parseLRC("[00:01.00] Hello\n[00:05.00]\n[00:09.00] World")
    check("empty line kept as instrumental", lines.count == 3 && lines[1].isInstrumental)
}
check("metadata and junk ignored", parseLRC("[ar:Whitney]\n[ti:Song]\nno timestamp\n[00:03.00] Real line").map(\.text) == ["Real line"])
check("no fraction accepted", parseLRC("[00:07] Seven").first?.time == 7)
check("CRLF tolerated", parseLRC("[00:01.00] A\r\n[00:02.00] B").count == 2)

print("Timeline")
let t = LyricsTimeline(lines: [LyricLine(time: 10, text: "one"), LyricLine(time: 20, text: ""), LyricLine(time: 30, text: "three")])
check("lead-in has no active line", t.activeIndex(at: 0) == nil && t.activeIndex(at: 9.99) == nil)
check("lead-in next is first line", t.next(at: 0)?.text == "one")
check("exactly on a line", t.activeIndex(at: 10) == 0)
check("between lines keeps previous", t.activeIndex(at: 19.9) == 0)
check("moves at boundary", t.activeIndex(at: 20) == 1 && t.next(at: 20)?.text == "three")
check("after last stays on last", t.activeIndex(at: 500) == 2 && t.next(at: 500) == nil)
let empty = LyricsTimeline(lines: [])
check("empty timeline", empty.activeIndex(at: 5) == nil && empty.next(at: 5) == nil)

print("Pill state")
let snap = PlaybackSnapshot(trackId: "x", title: "Song", artist: "Band", album: "LP", duration: 200, position: 15, state: .playing)
check("no spotify", PillState.derive(snapshot: nil, lyrics: .loading, position: 0) == .waitingForSpotify)
check("no lyrics", PillState.derive(snapshot: snap, lyrics: .unavailable, position: 15) == .noLyrics(title: "Song", artist: "Band"))
check("loading shows subtitle", PillState.derive(snapshot: snap, lyrics: .loading, position: 15) == .lyrics(line: nil, subtitle: "Song · Band", paused: false))
check("lead-in shows subtitle", PillState.derive(snapshot: snap, lyrics: .synced(t), position: 5) == .lyrics(line: nil, subtitle: "Song · Band", paused: false))
check("active line", PillState.derive(snapshot: snap, lyrics: .synced(t), position: 15) == .lyrics(line: "one", subtitle: "Song · Band", paused: false))
check("instrumental marker", PillState.derive(snapshot: snap, lyrics: .synced(t), position: 25) == .lyrics(line: "♪ ♪ ♪", subtitle: "Song · Band", paused: false))
let pausedSnap = PlaybackSnapshot(trackId: "x", title: "Song", artist: "Band", album: "LP", duration: 200, position: 15, state: .paused)
check("paused flag", PillState.derive(snapshot: pausedSnap, lyrics: .synced(t), position: 15) == .lyrics(line: "one", subtitle: "Song · Band", paused: true))

print("Position interpolation")
check("advances while playing", snap.position(after: 2.5) == 17.5)
check("clamped to duration", snap.position(after: 1000) == 200)
check("frozen while paused", pausedSnap.position(after: 2.5) == 15)
check("never goes backwards", snap.position(after: -1) == 15)

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
