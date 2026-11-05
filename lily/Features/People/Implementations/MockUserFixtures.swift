import Foundation

/// What the fixture people wrote about themselves; a name without a line has no bio, like most accounts. Marta's is
/// the line Laurel's contract sample carries.
nonisolated enum MockUserFixtures {
    private static let bios: [String: String] = [
        "Marta": "Padel on Sundays, football when it rains.",
        "Jonas": "Midfielder. Bad at penalties, good at excuses.",
        "Dev": "Basketball since school; ask me about courts in Berlin.",
    ]

    static func bio(of userID: String) -> String? {
        bios.first { MockGroupFixtures.memberID(for: $0.key) == userID }?.value
    }
}
