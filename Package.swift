// swift-tools-version:5.9
import PackageDescription

// Tests are a plain executable (`swift run LyricsCoreTests`) because the
// Command Line Tools ship neither XCTest nor the Swift Testing macros.
let package = Package(
    name: "FloatingLyrics",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "LyricsCore"),
        .executableTarget(name: "FloatingLyrics", dependencies: ["LyricsCore"]),
        .executableTarget(name: "LyricsCoreTests", dependencies: ["LyricsCore"]),
    ]
)
