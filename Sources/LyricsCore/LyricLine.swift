import Foundation

public struct LyricLine: Equatable, Codable, Sendable {
    /// Seconds from the start of the track.
    public let time: TimeInterval
    public let text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }

    /// LRC files mark instrumental gaps as a timestamp with no text.
    public var isInstrumental: Bool { text.isEmpty }
}
