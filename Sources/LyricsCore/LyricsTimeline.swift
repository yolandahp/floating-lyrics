import Foundation

/// Pure lookup of which line is active at a given playback position.
public struct LyricsTimeline: Equatable, Sendable {
    public let lines: [LyricLine]

    public init(lines: [LyricLine]) {
        self.lines = lines
    }

    /// Index of the last line whose time is <= `position`, or nil during the lead-in.
    public func activeIndex(at position: TimeInterval) -> Int? {
        // Binary search for the last line with time <= position.
        var lo = 0, hi = lines.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= position { lo = mid + 1 } else { hi = mid }
        }
        return lo == 0 ? nil : lo - 1
    }

    public func current(at position: TimeInterval) -> LyricLine? {
        activeIndex(at: position).map { lines[$0] }
    }

    public func next(at position: TimeInterval) -> LyricLine? {
        let i = activeIndex(at: position).map { $0 + 1 } ?? 0
        return i < lines.count ? lines[i] : nil
    }
}
