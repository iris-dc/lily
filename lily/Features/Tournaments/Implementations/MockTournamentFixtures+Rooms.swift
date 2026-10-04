import Foundation

/// The rooms of the fixture tournaments as the group mock lists them, and the rosters behind them; a file of its own so
/// the fixture enum stays under the type-body limit.
nonisolated extension MockTournamentFixtures {
    /// The rooms the group mock lists for the tournaments: the caller owns the Kickers Cup's, is a member of the
    /// table-tennis one and has no membership in the Padel Open's until they accept the invite.
    static func rooms(now: Date) -> [SportGroup] {
        make(now: now).map { detail in
            let tournament = detail.tournament
            let lastMessageAt = now.addingTimeInterval(-tableTennisLastMessageHoursAgo * secondsPerHour)
            return room(for: tournament,
                        organizerName: tournament.organizerName,
                        memberCount: playerCount(of: detail),
                        membership: callerMembership(in: detail),
                        lastMessageId: MockChatFixtures.newestMessageID(for: tournament.id),
                        lastMessageAt: tournament.id == tableTennisID ? lastMessageAt : nil)
        }
    }

    /// The caller's row in a tournament's room: owner as its organiser, member through an entry, none otherwise.
    private static func callerMembership(in detail: TournamentDetail) -> GroupMembership? {
        let tournament = detail.tournament
        let isOrganizer = tournament.organizerUserId == callerMarker
        let callerEntry = detail.entry(containing: callerMarker)
        guard isOrganizer || callerEntry != nil else { return nil }
        return GroupMembership(role: isOrganizer ? .owner : .member,
                               joinedAt: isOrganizer ? tournament.createdAt : (callerEntry?.createdAt ?? tournament.createdAt),
                               lastReadMessageId: MockChatFixtures.newestMessageID(for: tournament.id))
    }

    /// A tournament's room as the backend shapes one: under the tournament's id, named after it, its visibility and
    /// type, the organiser as owner, `maxEntries * teamSize + 1` seats, no group powers.
    static func room(for tournament: Tournament,
                     organizerName: String,
                     memberCount: Int,
                     membership: GroupMembership?,
                     lastMessageId: String? = nil,
                     lastMessageAt: Date? = nil) -> SportGroup {
        SportGroup(id: tournament.id,
                   name: tournament.name,
                   visibility: tournament.visibility,
                   type: tournament.type,
                   ownerName: organizerName,
                   memberCount: memberCount,
                   maxMembers: tournament.maxEntries * tournament.teamSize + 1,
                   channelEpoch: tournament.channelEpoch,
                   membersCanCreateEvents: false,
                   membersCanInvite: false,
                   lastMessageId: lastMessageId,
                   lastMessageAt: lastMessageAt,
                   createdAt: tournament.createdAt,
                   membership: membership,
                   kind: .tournament)
    }

    /// The other members of a tournament's room (never the caller): every player in, and the organiser when they do
    /// not play. Oldest first.
    static func roster(for tournamentID: String, now: Date) -> [GroupMember] {
        guard let detail = make(now: now).first(where: { $0.id == tournamentID }) else { return [] }
        var members = detail.entries.flatMap { entry in
            entry.members.filter { $0.userId != callerMarker }.map {
                GroupMember(userId: $0.userId, displayName: $0.displayName, role: .member, joinedAt: entry.createdAt)
            }
        }
        let organizer = detail.tournament
        if organizer.organizerUserId != callerMarker, !members.contains(where: { $0.userId == organizer.organizerUserId }) {
            members.insert(GroupMember(userId: organizer.organizerUserId,
                                       displayName: organizer.organizerName,
                                       role: .owner,
                                       joinedAt: organizer.createdAt),
                           at: 0)
        }
        return members
    }
}
