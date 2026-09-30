import Foundation

nonisolated extension MockEventFixtures {
    /// Every person the fixture events and rosters name; the mock participant lists draw from it, so a participant's
    /// profile resolves against the group mock.
    static let participantNames = ["Marta", "Jonas", "Ayşe", "Dev", "Aiko", "Sam", "Noor", "Tom", "Ines", "Luca", "Priya"]

    /// The host's own row is written this long before the game starts; each further participant an hour later.
    static let hostJoinLead: TimeInterval = 7 * 24 * 60 * 60
    static let joinSpacing: TimeInterval = 60 * 60

    /// `count` names other than the host, starting at an offset drawn from the event's id, so neighbouring fixtures
    /// list different people and every launch lists the same ones.
    static func participantNames(for event: SportEvent, count: Int) -> [String] {
        let pool = participantNames.filter { $0 != event.hostName }
        guard count > 0, !pool.isEmpty else { return [] }
        let start = event.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % pool.count
        return (0..<min(count, pool.count)).map { pool[(start + $0) % pool.count] }
    }
}
