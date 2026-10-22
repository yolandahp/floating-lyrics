import Foundation
import Combine
import LyricsCore

/// Owns the polling loop and the lyrics lookup; publishes a `PillState` for the view.
@MainActor
final class LyricsViewModel: ObservableObject {
    @Published private(set) var state: PillState = .waitingForSpotify

    private static let pollInterval: TimeInterval = 1.0
    private static let tickInterval: TimeInterval = 0.1

    private let spotify = SpotifyClient()
    private let lrclib = LRCLibClient()

    private var snapshot: PlaybackSnapshot?
    private var snapshotTakenAt = Date()
    private var lyrics: LyricsStatus = .loading
    private var lyricsTask: Task<Void, Never>?
    private var timers: [Timer] = []
    private var notificationObserver: NSObjectProtocol?

    func start() {
        poll()
        timers = [
            Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            },
            // Interpolates position between polls so lines flip on time, not on the next poll.
            Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.render() }
            },
        ]
        // Play, pause, seek and track changes arrive instantly instead of on the next poll.
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: SpotifyClient.playbackChangedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        Task { [spotify] in
            let snap = await spotify.snapshot()
            apply(snap)
        }
    }

    private func apply(_ snap: PlaybackSnapshot?) {
        let trackChanged = snap?.trackId != snapshot?.trackId
        snapshot = snap
        snapshotTakenAt = Date()
        if trackChanged {
            lyricsTask?.cancel()
            lyrics = .loading
            if let snap { lyricsTask = Task { await self.loadLyrics(for: snap) } }
        }
        render()
    }

    private func loadLyrics(for track: PlaybackSnapshot) async {
        let lines = await lrclib.lyrics(for: track)
        // The track may have changed while we waited; the newer task owns the state then.
        guard !Task.isCancelled, snapshot?.trackId == track.trackId else { return }
        lyrics = lines.map { .synced(LyricsTimeline(lines: $0)) } ?? .unavailable
        render()
    }

    private func render() {
        let position = snapshot?.position(after: Date().timeIntervalSince(snapshotTakenAt)) ?? 0
        let new = PillState.derive(snapshot: snapshot, lyrics: lyrics, position: position)
        if new != state { state = new }
    }
}
