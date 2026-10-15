import Foundation

/// What the intro's miniature screens show when nothing live is there to show: the mock feed's first events, the same
/// for everyone like a screenshot, the room the groups slide draws and the tournament whose bracket the last slide
/// shows. Proper nouns, so not localized.
nonisolated enum IntroFixtures {
    static let groupName = "Kreuzberg Kickers"
    static let memberCount = 12
    /// Who announces the game and asks the question in the chat miniature, and who organises the tournament: the mock
    /// rooms' first sender.
    static let senderName = MockChatFixtures.senders[0]

    /// Both semi-finals of the fixture cup, so the finalists stand in the final the miniature's second column shows.
    private static let semiFinals = [
        MockTournamentFixtures.Result(matchID: TournamentSchedule.matchID(round: 1, position: 1), scoreA: 3, scoreB: 1),
        MockTournamentFixtures.Result(matchID: TournamentSchedule.matchID(round: 1, position: 2), scoreA: 2, scoreB: 0),
    ]

    /// The live preview's count, so samples and live data fill the cropped frame to the same length.
    static func events(now: Date) -> [SportEvent] {
        MockEventFixtures.make(now: now, count: AppConfig.Events.landingPreviewCount)
    }

    /// The mock's cup under way: organised by the room's sender rather than the mock's caller, whose seat would read
    /// "Organised by You" to someone who has not signed in, started, and both semi-finals recorded.
    static func tournament(now: Date) -> TournamentDetail {
        let organizerID = MockGroupFixtures.memberID(for: senderName)
        let started = MockTournamentFixtures.kickersCup(now: now, organizerUserID: organizerID, organizerName: senderName)
            .starting(at: now)
        return semiFinals.reduce(started) { detail, result in
            guard let match = detail.match(id: result.matchID) else { return detail }
            return detail.settling(match.recording(result.scoreA, result.scoreB, by: organizerID, at: now), at: now)
        }
    }
}
