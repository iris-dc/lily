import SwiftUI

/// The pinned bar over the transcript: the newest pin first; a tap brings its message on screen with the wash a quote
/// gets, then shows the pin before it, round to the newest after the oldest, as Telegram steps through pins. A change
/// of the pins shows the newest again.
extension ChatTranscript {
    @ViewBuilder var pinnedBar: some View {
        let pins = viewModel.pins
        if !pins.isEmpty {
            let shown = min(shownPinIndex ?? pins.count - 1, pins.count - 1)
            PinnedBar(pins: pins,
                      shownIndex: shown,
                      canUnpin: viewModel.canChangePins,
                      onTap: {
                          reveal(pins[shown].quote)
                          shownPinIndex = shown == 0 ? pins.count - 1 : shown - 1
                      },
                      onUnpin: { Task { await viewModel.unpin(pins[shown].messageId) } })
                .onChange(of: pins.map(\.messageId)) { shownPinIndex = nil }
        }
    }
}
