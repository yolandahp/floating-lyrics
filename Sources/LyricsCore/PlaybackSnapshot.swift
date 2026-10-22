import Foundation

/// What the player reported at one instant.
public struct PlaybackSnapshot: Equatable, Sendable {
    public enum State: String, Sendable { case playing, paused }

    public let trackId: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let position: TimeInterval
    public let state: State

    public init(trackId: String, title: String, artist: String, album: String,
                duration: TimeInterval, position: TimeInterval, state: State) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.state = state
    }

    /// Where playback is `elapsed` seconds after this snapshot was taken.
    public func position(after elapsed: TimeInterval) -> TimeInterval {
        guard state == .playing else { return position }
        return min(position + max(elapsed, 0), duration)
    }
}
