import Foundation
import LyricsCore

/// Fetches synced lyrics from LRCLIB and caches results on disk per Spotify track id.
/// Hits are kept forever; misses expire so a song that gains lyrics later is retried.
final class LRCLibClient {
    private static let missLifetime: TimeInterval = 7 * 24 * 3600
    private static let userAgent = "FloatingLyrics/0.1 (local macOS app)"

    private let cacheDir: URL
    private let session: URLSession

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("FloatingLyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    private struct CacheEntry: Codable {
        let lines: [LyricLine]?
        let fetchedAt: Date
    }

    private struct Record: Decodable {
        let syncedLyrics: String?
        let duration: Double?
    }

    /// nil means no synced lyrics could be found.
    func lyrics(for track: PlaybackSnapshot) async -> [LyricLine]? {
        let file = cacheFile(for: track.trackId)
        if let cached = readCache(file) { return cached.lines }
        guard let lines = await fetch(track) else { return nil } // network failure: don't cache
        writeCache(CacheEntry(lines: lines, fetchedAt: Date()), to: file)
        return lines
    }

    // MARK: Cache

    private func cacheFile(for trackId: String) -> URL {
        cacheDir.appendingPathComponent(trackId.replacingOccurrences(of: ":", with: "_") + ".json")
    }

    private func readCache(_ file: URL) -> CacheEntry? {
        guard let data = try? Data(contentsOf: file),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else { return nil }
        let isExpiredMiss = entry.lines == nil && Date().timeIntervalSince(entry.fetchedAt) > Self.missLifetime
        return isExpiredMiss ? nil : entry
    }

    private func writeCache(_ entry: CacheEntry, to file: URL) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: file, options: .atomic)
    }

    // MARK: Network

    /// Outer nil: the request failed. Inner nil: LRCLIB has no synced lyrics for this track.
    private func fetch(_ track: PlaybackSnapshot) async -> [LyricLine]?? {
        // Exact lookup first; it needs the duration to match within a couple of seconds.
        let exact = await request("get", [
            ("track_name", track.title), ("artist_name", track.artist),
            ("album_name", track.album), ("duration", String(Int(track.duration.rounded()))),
        ])
        switch exact {
        case .failure: return nil
        case .success(let data):
            if let lines = (try? JSONDecoder().decode(Record.self, from: data)).flatMap(synced) { return .some(lines) }
        }
        // Fall back to search: Spotify's duration or album often differ from LRCLIB's.
        guard case .success(let data) = await request("search", [("track_name", track.title), ("artist_name", track.artist)]),
              let records = try? JSONDecoder().decode([Record].self, from: data) else { return nil }
        let candidate = records.first { r in
            r.syncedLyrics != nil && abs((r.duration ?? -100) - track.duration) <= 5
        }
        return .some(candidate.flatMap(synced))
    }

    private func synced(_ record: Record) -> [LyricLine]? {
        guard let text = record.syncedLyrics else { return nil }
        let lines = parseLRC(text)
        return lines.isEmpty ? nil : lines
    }

    private enum RequestError: Error { case status(Int) }

    private func request(_ endpoint: String, _ query: [(String, String)]) async -> Result<Data, Error> {
        var comps = URLComponents(string: "https://lrclib.net/api/\(endpoint)")!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        var req = URLRequest(url: comps.url!)
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 404 is LRCLIB's "not found" for /get; treat it as an empty success, not a failure.
            if status == 404 { return .success(Data("{}".utf8)) }
            guard status == 200 else { return .failure(RequestError.status(status)) }
            return .success(data)
        } catch {
            NSLog("LRCLIB \(endpoint) failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
