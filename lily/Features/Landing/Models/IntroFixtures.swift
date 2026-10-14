import Foundation

/// What the intro's miniature screens show when nothing live is there to show: the mock feed's first games, the same
/// for everyone like a screenshot, and the room the chat slide draws. Proper nouns, so not localized.
nonisolated enum IntroFixtures {
    static let groupName = "Kreuzberg Kickers"
    static let memberCount = 12
    /// Who announces the game and asks the question in the chat miniature: the mock rooms' first sender.
    static let senderName = MockChatFixtures.senders[0]

    /// The live preview's count, so samples and live data fill the cropped frame to the same length.
    static func events(now: Date) -> [SportEvent] {
        MockEventFixtures.make(now: now, count: AppConfig.Events.landingPreviewCount)
    }
}
