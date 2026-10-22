import Foundation

/// Parses LRC text (`[mm:ss.xx] words`) into lines sorted by time.
/// Metadata tags like `[ar:...]` and lines without a timestamp are dropped.
public func parseLRC(_ text: String) -> [LyricLine] {
    let pattern = #"^\[(\d+):(\d{1,2})(?:\.(\d{1,3}))?\]\s?(.*)$"#
    let regex = try! NSRegularExpression(pattern: pattern)
    var lines: [LyricLine] = []
    for raw in text.components(separatedBy: .newlines) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        let range = NSRange(line.startIndex..., in: line)
        guard let m = regex.firstMatch(in: line, range: range) else { continue }
        func group(_ i: Int) -> String? {
            let r = m.range(at: i)
            guard r.location != NSNotFound, let sr = Range(r, in: line) else { return nil }
            return String(line[sr])
        }
        guard let minutes = group(1).flatMap(Double.init),
              let seconds = group(2).flatMap(Double.init) else { continue }
        var fraction = 0.0
        if let f = group(3), !f.isEmpty {
            fraction = Double("0." + f) ?? 0
        }
        let words = (group(4) ?? "").trimmingCharacters(in: .whitespaces)
        lines.append(LyricLine(time: minutes * 60 + seconds + fraction, text: words))
    }
    return lines.sorted { $0.time < $1.time }
}
