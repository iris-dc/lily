import Foundation

/// What the intro's miniature screens show when nothing live is there to show: the mock feed's first games, the same
/// for everyone like a screenshot, and the room the chat slide draws. Proper nouns, so not localized.
nonisolated enum IntroFixtures {
    static let groupName = "Kreuzberg Kickers"
    static let memberCount = 12
    /// Who announces the game and asks the question in the chat miniature: the mock rooms' first sender.
    static let senderName = MockChatFixtures.senders[0]

    /// As many cards as the live preview is trimmed to, so the miniature's cropped frame shows one length for samples
    /// and live data.
    static func events(now: Date) -> [SportEvent] {
        MockEventFixtures.make(now: now, count: AppConfig.Events.landingPreviewCount)
    }
}
