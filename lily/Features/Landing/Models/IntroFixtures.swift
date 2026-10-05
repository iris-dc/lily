import Foundation

/// What the intro's miniature screens show when nothing live is there to show: the mock feed's first games, the same
/// for everyone like a screenshot, and the room the chat slide draws. Proper nouns, so not localized.
nonisolated enum IntroFixtures {
    /// Cards in the Explore miniature; the frame crops whatever runs past its bottom.
    static let eventCount = 3
    static let groupName = "Kreuzberg Kickers"
    static let memberCount = 12
    /// Who announces the game and asks the question in the chat miniature: the mock rooms' first sender.
    static let senderName = MockChatFixtures.senders[0]

    static func events(now: Date) -> [SportEvent] {
        MockEventFixtures.make(now: now, count: eventCount)
    }
}
