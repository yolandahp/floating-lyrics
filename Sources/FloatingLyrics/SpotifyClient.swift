import Foundation
import LyricsCore

/// Asks the Spotify desktop app what it is doing, via Apple Events.
/// Never launches Spotify; returns nil when it is not running or has nothing loaded.
// All state is immutable after init and the script only ever runs on the serial queue.
final class SpotifyClient: @unchecked Sendable {
    /// Spotify posts this on play, pause, seek and track change.
    static let playbackChangedNotification = Notification.Name("com.spotify.client.PlaybackStateChanged")

    // NSAppleScript is documented as main-thread only, but a blocking Apple Event on the main
    // thread would freeze the pill if Spotify stalls. One serial queue keeps calls ordered and
    // off the UI; this has been reliable in practice.
    private let queue = DispatchQueue(label: "FloatingLyrics.spotify", qos: .utility)
    private let script = NSAppleScript(source: """
        tell application "Spotify"
            if it is not running then return ""
            if player state is stopped then return ""
            set t to current track
            return (id of t) & tab & (name of t) & tab & (artist of t) & tab & (album of t) & tab & \
                (duration of t) & tab & (player position) & tab & (player state as string)
        end tell
        """)!

    func snapshot() async -> PlaybackSnapshot? {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.readSnapshot()) }
        }
    }

    private func readSnapshot() -> PlaybackSnapshot? {
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let raw = result.stringValue, !raw.isEmpty else { return nil }
        let f = raw.components(separatedBy: "\t")
        guard f.count == 7,
              let durationMs = Double(f[4]),
              let position = Double(f[5]),
              let state = PlaybackSnapshot.State(rawValue: f[6]) else { return nil }
        return PlaybackSnapshot(trackId: f[0], title: f[1], artist: f[2], album: f[3],
                                duration: durationMs / 1000, position: position, state: state)
    }
}
