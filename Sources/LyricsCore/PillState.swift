import Foundation

/// Where the lyrics lookup for the current track stands.
public enum LyricsStatus: Equatable, Sendable {
    case loading
    case unavailable
    case synced(LyricsTimeline)
}

/// Everything the pill needs to draw itself. Pure data, derived by `PillState.derive`.
public enum PillState: Equatable, Sendable {
    case waitingForSpotify
    case noLyrics(title: String, artist: String)
    /// `line` is nil during the lead-in or while lyrics are still loading; show `subtitle` then.
    case lyrics(line: String?, subtitle: String, paused: Bool)

    public static let instrumentalMarker = "♪ ♪ ♪"

    public static func derive(snapshot: PlaybackSnapshot?, lyrics: LyricsStatus, position: TimeInterval) -> PillState {
        guard let snapshot else { return .waitingForSpotify }
        let subtitle = "\(snapshot.title) · \(snapshot.artist)"
        let paused = snapshot.state != .playing
        switch lyrics {
        case .unavailable:
            return .noLyrics(title: snapshot.title, artist: snapshot.artist)
        case .loading:
            return .lyrics(line: nil, subtitle: subtitle, paused: paused)
        case .synced(let timeline):
            let line = timeline.current(at: position).map { $0.isInstrumental ? instrumentalMarker : $0.text }
            return .lyrics(line: line, subtitle: subtitle, paused: paused)
        }
    }
}
