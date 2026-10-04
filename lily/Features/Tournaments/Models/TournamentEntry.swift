import Foundation

/// One player of an entry: their id and the name snapshotted when they joined it.
nonisolated struct EntryMember: Hashable, Codable, Sendable {
    let userId: String
    let displayName: String
}

/// One entry of a tournament: a player entered alone (named after themselves, their own captain) or a team its captain
/// named. Members are in join order, the captain first until they leave; `seed` is the entry's place in registration
/// order, which is the default seeding.
nonisolated struct TournamentEntry: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let tournamentId: String
    let name: String
    private(set) var captainUserId: String
    private(set) var members: [EntryMember]
    let seed: Int
    let status: EntryStatus
    let createdAt: Date

    init(id: String,
         tournamentId: String,
         name: String,
         captainUserId: String,
         members: [EntryMember],
         seed: Int,
         status: EntryStatus = .registered,
         createdAt: Date) {
        self.id = id
        self.tournamentId = tournamentId
        self.name = name
        self.captainUserId = captainUserId
        self.members = members
        self.seed = seed
        self.status = status
        self.createdAt = createdAt
    }

    var memberCount: Int { members.count }
    var isRegistered: Bool { status == .registered }

    func isFull(teamSize: Int) -> Bool {
        memberCount >= teamSize
    }

    func contains(userID: String?) -> Bool {
        userID != nil && members.contains { $0.userId == userID }
    }

    func isCaptain(_ userID: String?) -> Bool {
        userID != nil && captainUserId == userID
    }

    /// A teammate joined.
    func adding(_ member: EntryMember) -> TournamentEntry {
        var copy = self
        copy.members.append(member)
        return copy
    }

    /// A player left or was removed; the captaincy passes to the next member. `nil` once the entry is empty, which the
    /// backend deletes outright while registration is open.
    func removing(userID: String) -> TournamentEntry? {
        var copy = self
        copy.members.removeAll { $0.userId == userID }
        guard let next = copy.members.first else { return nil }
        if copy.captainUserId == userID { copy.captainUserId = next.userId }
        return copy
    }
}
