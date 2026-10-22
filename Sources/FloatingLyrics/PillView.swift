import SwiftUI
import LyricsCore

/// Presentation-only state the pill needs besides the lyrics: hover and minimize.
/// Lives in an ObservableObject because the toolchain here cannot expand SwiftUI's @State macro.
@MainActor
final class PillUIState: ObservableObject {
    @Published var hovering = false
    @Published var minimized = false
}

struct PillView: View {
    @ObservedObject var model: LyricsViewModel
    @ObservedObject var ui: PillUIState

    var body: some View {
        Group {
            if ui.minimized { dot } else { pill }
        }
        .onHover { ui.hovering = $0 }
    }

    // MARK: Minimized

    private var dot: some View {
        ZStack {
            Circle().fill(Theme.background)
                .overlay(Circle().stroke(Theme.edge))
            Circle().fill(Theme.accent).frame(width: 7, height: 7)
        }
        .contentShape(Circle())
        .onTapGesture { ui.minimized = false }
    }

    // MARK: Expanded

    private var pill: some View {
        ZStack(alignment: .topTrailing) {
            content
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(Theme.background))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.edge))
                .opacity(isPaused ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.2), value: isPaused)

            if ui.hovering {
                HStack(spacing: 6) {
                    control("minus") { ui.minimized = true }
                    control("xmark") { NSApp.terminate(nil) }
                }
                .padding(8)
                .transition(.opacity)

                resizeHint
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: ui.hovering)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .waitingForSpotify:
            quiet("Waiting for Spotify…")
        case let .noLyrics(title, artist):
            VStack(spacing: 2) {
                quiet("No lyrics for this song")
                quiet("\(title) · \(artist)", size: 11)
            }
        case let .lyrics(line, subtitle, _):
            if let line {
                Text(line)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .id(line) // a new line fades in instead of snapping
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            } else {
                quiet(subtitle)
            }
        }
    }

    private var isPaused: Bool {
        if case let .lyrics(_, _, paused) = model.state { return paused }
        return false
    }

    /// Visual hint only; `ResizeHandleView` in the panel does the actual resizing.
    private var resizeHint: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.35))
            .frame(width: 4, height: 22)
            .padding(.trailing, 8)
    }

    private func quiet(_ text: String, size: CGFloat = 13) -> some View {
        Text(text)
            .font(.system(size: size))
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

enum Theme {
    static let background = Color(white: 0.07, opacity: 0.92)
    static let edge = Color.white.opacity(0.1)
    static let accent = Color(red: 0.11, green: 0.73, blue: 0.33)
    static let cornerRadius: CGFloat = 20
}
