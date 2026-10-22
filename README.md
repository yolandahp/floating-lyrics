# Floating Lyrics

A small macOS pill that floats the current Spotify lyric line over every app, so you can sing along while working.

- Works with the Spotify desktop app only (asked via Apple Events, no login, no API keys).
- Synced lyrics come from [LRCLIB](https://lrclib.net) and are cached in `~/Library/Caches/FloatingLyrics`.
- Always on top, draggable, resizable from its right edge, remembers its position and size. Hover for minimize (shrinks to a dot) and close (quits).
- A menu bar icon shows it is running: show/hide the pill, reset its position, quit.

## Build and run

Needs only the Xcode Command Line Tools (Swift 6).

```sh
./scripts/bundle.sh          # builds dist/FloatingLyrics.app
open dist/FloatingLyrics.app
```

The first launch asks for permission to control Spotify. Quit from the menu bar icon or the × on the pill.

## Tests

The Command Line Tools ship no XCTest, so the core tests are a plain executable:

```sh
swift run LyricsCoreTests
```

## Layout

- `Sources/LyricsCore`: pure logic, no I/O. LRC parsing, "which line is active at time t", position interpolation, and deriving the pill's state.
- `Sources/FloatingLyrics`: the app. `SpotifyClient` (Apple Events), `LRCLibClient` (HTTP + cache), `LyricsViewModel` (polling loop), `PillView` (SwiftUI), `FloatingPanel` (NSPanel + resize handle), `StatusBarController` (menu bar item).
