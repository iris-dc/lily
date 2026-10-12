import Foundation
import Testing
@testable import lily

/// Who may do what on the tournament detail, for every status and every kind of caller.
struct TournamentPermissionsTests {
    private let me = TestFixtures.user.id
    private let now = Date(timeIntervalSince1970: 1_799_000_000)

    private func permissions(for tournament: Tournament,
                             as userID: String?,
                             chatEnabled: Bool = true) -> TournamentPermissions {
        TournamentPermissions(tournament: tournament, userID: userID, now: now, chatEnabled: chatEnabled)
    }

    @Test func aGuestGetsNothing() {
        for status in [TournamentStatus.registration, .inProgress, .completed, .cancelled] {
            #expect(permissions(for: .fixture(status: status), as: nil) == .none, "\(status)")
        }
    }

    @Test func theOrganiserEditsAndCancelsUntilTheTournamentIsOverAndRemovesEntriesInRegistrationOnly() {
        let registration = permissions(for: .fixture(organizerUserId: me), as: me)
        #expect(registration.canEdit && registration.canCancel && registration.canRemoveEntries)

        let inProgress = permissions(for: .fixture(status: .inProgress, organizerUserId: me), as: me)
        #expect(inProgress.canEdit && inProgress.canCancel && !inProgress.canRemoveEntries)

        for status in [TournamentStatus.completed, .cancelled] {
            let over = permissions(for: .fixture(status: status, organizerUserId: me), as: me)
            #expect(!over.canEdit && !over.canCancel && !over.canRemoveEntries, "\(status)")
        }
    }

    @Test func chatIsForTheOrganiserAndEntrantsWhileTheFlagIsOn() {
        #expect(permissions(for: .fixture(organizerUserId: me), as: me).canOpenChat)
        #expect(permissions(for: .fixture(myEntryId: "e1"), as: me).canOpenChat)
        #expect(!permissions(for: .fixture(), as: me).canOpenChat, "an outsider")

        #expect(!permissions(for: .fixture(organizerUserId: me), as: me, chatEnabled: false).canOpenChat)
        #expect(!permissions(for: .fixture(myEntryId: "e1"), as: me, chatEnabled: false).canOpenChat)
        #expect(!permissions(for: .fixture(), as: me, chatEnabled: false).canOpenChat)
    }

    @Test func invitingIsTheOrganisersAndEntrantsUntilTheDeadline() {
        #expect(permissions(for: .fixture(organizerUserId: me), as: me).canInvite)
        #expect(permissions(for: .fixture(myEntryId: "e1"), as: me).canInvite)
        #expect(!permissions(for: .fixture(), as: me).canInvite, "an outsider")

        let closed = now.addingTimeInterval(-60)
        #expect(!permissions(for: .fixture(registrationClosesAt: closed, organizerUserId: me), as: me).canInvite)
        #expect(!permissions(for: .fixture(registrationClosesAt: closed, myEntryId: "e1"), as: me).canInvite)
        #expect(!permissions(for: .fixture(status: .inProgress, organizerUserId: me), as: me).canInvite)
        #expect(!permissions(for: .fixture(status: .inProgress, myEntryId: "e1"), as: me).canInvite)
    }

    @Test func reportingIsForAnyoneSignedInButTheOrganiser() {
        #expect(permissions(for: .fixture(myEntryId: "e1"), as: me).canReport)
        #expect(permissions(for: .fixture(), as: me).canReport, "an outsider")
        #expect(permissions(for: .fixture(status: .completed), as: me).canReport, "also once over")
        #expect(!permissions(for: .fixture(organizerUserId: me), as: me).canReport)
    }

    @Test func theOrganiserProfileOpensForEveryoneSignedInButTheOrganiser() {
        let tournament = Tournament.fixture(organizerUserId: "seed-marta", organizerName: "Marta")
        let marta = UserProfileDestination(userId: "seed-marta", displayName: "Marta")
        #expect(permissions(for: tournament, as: me).organizerProfile == marta, "an outsider")
        #expect(permissions(for: .fixture(myEntryId: "e1"), as: me).organizerProfile == marta, "an entrant")
        #expect(permissions(for: .fixture(organizerUserId: me), as: me).organizerProfile == nil)
    }

    /// A knockout of teams of five, which starts at two entries.
    private func knockout(entryCount: Int, organizerUserId: String = "seed-marta", myEntryId: String? = nil) -> Tournament {
        .fixture(format: .singleElimination,
                 teamSize: 5,
                 entryCount: entryCount,
                 organizerUserId: organizerUserId,
                 myEntryId: myEntryId)
    }

    @Test func startIsOfferedToTheOrganiserInRegistrationAndEnabledAtTheMinimum() {
        let short = permissions(for: knockout(entryCount: 1, organizerUserId: me), as: me)
        #expect(short.showsStart && !short.canStart)
        #expect(short.startBlockedReason == AppBranding.Tournaments.startNeeds(2, teamSize: 5))

        let enough = permissions(for: knockout(entryCount: 4, organizerUserId: me), as: me)
        #expect(enough.showsStart && enough.canStart && enough.startBlockedReason == nil)

        let entrant = permissions(for: knockout(entryCount: 4, myEntryId: "e1"), as: me)
        #expect(!entrant.showsStart && !entrant.canStart && entrant.startBlockedReason == nil)

        let started = permissions(for: .fixture(status: .inProgress, entryCount: 4, organizerUserId: me), as: me)
        #expect(!started.showsStart && !started.canStart && started.startBlockedReason == nil)
    }

    @Test func joiningATeamIsOfferedToAnyoneSignedInAndNotInWhileRegistrationIsOpenOnATeamTournament() {
        #expect(permissions(for: .fixture(teamSize: 2), as: me).canJoinTeams, "an outsider")
        #expect(permissions(for: .fixture(teamSize: 2, maxEntries: 1, entryCount: 1), as: me).canJoinTeams,
                "a full field still has teams to join: joining one adds no entry")
        #expect(permissions(for: .fixture(teamSize: 2, organizerUserId: me), as: me).canJoinTeams, "the organiser not in")

        #expect(!permissions(for: .fixture(teamSize: 2, myEntryId: "e1"), as: me).canJoinTeams, "already in")
        #expect(!permissions(for: .fixture(teamSize: 1), as: me).canJoinTeams, "players alone")
        #expect(!permissions(for: .fixture(teamSize: 2, registrationClosesAt: now.addingTimeInterval(-60)), as: me).canJoinTeams)
        #expect(!permissions(for: .fixture(status: .inProgress, teamSize: 2), as: me).canJoinTeams)
        #expect(!permissions(for: .fixture(teamSize: 2), as: nil).canJoinTeams, "a guest")
    }

    @Test func theMenuShowsWhenAnythingInItDoes() {
        #expect(permissions(for: .fixture(status: .completed), as: me).showsMenu, "an outsider may still report")
        let silent = permissions(for: .fixture(status: .completed, organizerUserId: me), as: me, chatEnabled: false)
        #expect(!silent.showsMenu)
        #expect(!TournamentPermissions.none.showsMenu)
    }
}

/// The view model's `permissions` is the rule over the loaded detail and the caller.
@MainActor
struct TournamentDetailPermissionsTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")

    @Test func permissionsAreNoneBeforeTheLoadAndFollowTheLoadedDetail() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(organizerUserId: TestFixtures.user.id))
        let viewModel = harness.makeDetailViewModel(for: destination)
        #expect(viewModel.permissions == .none)

        await viewModel.load()
        #expect(viewModel.permissions.canEdit && viewModel.permissions.showsStart)

        await viewModel.cancel()
        #expect(!viewModel.permissions.canEdit, "the value follows the detail")
    }
}
