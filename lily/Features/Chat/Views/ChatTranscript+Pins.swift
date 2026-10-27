import SwiftUI

/// The pinned bar over the transcript: the newest pin first; a tap brings its message on screen with the wash a quote
/// gets, then shows the pin before it, round to the newest after the oldest, as Telegram steps through pins
/// (`PinnedBarPosition`). A change of the pins shows the newest again (the transcript resets `shownPinIndex`, since the
/// bar itself is not there to see a change while there are no pins).
extension ChatTranscript {
    @ViewBuilder var pinnedBar: some View {
        let pins = viewModel.pins
        if !pins.isEmpty {
            let shown = PinnedBarPosition.shown(shownPinIndex, count: pins.count)
            PinnedBar(pins: pins,
                      shownIndex: shown,
                      canUnpin: viewModel.canChangePins,
                      onTap: {
                          reveal(pins[shown].quote)
                          shownPinIndex = PinnedBarPosition.steppedBack(from: shown, count: pins.count)
                      },
                      onUnpin: { Task { await viewModel.unpin(pins[shown].messageId) } })
        }
    }
}
