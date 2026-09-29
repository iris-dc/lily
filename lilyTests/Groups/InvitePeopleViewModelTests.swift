import Foundation
import Testing
@testable import lily

@MainActor
struct InvitePeopleViewModelTests {
    private let harness = GroupHarness()
    private let group = SportGroup.fixture(id: "g", role: .owner)
    private let marta = InviteCandidate.fixture(userId: "u-2", displayName: "Marta")
    private let ayse = InviteCandidate.fixture(userId: "u-3", displayName: "Ayşe", via: .event, viaName: "Sunset 5-a-side")
    private let noor = InviteCandidate.fixture(userId: "u-4", displayName: "Noor", isInvited: true)

    /// A view model over the sheet's candidates, opened once.
    private func openSheet(_ candidates: [InviteCandidate]) async -> InvitePeopleViewModel {
        harness.invites.candidatesResult = .success(candidates)
        let viewModel = harness.makeInvitePeopleViewModel(for: group)
        await viewModel.load()
        return viewModel
    }

    @Test func loadListsTheCandidatesAndTheStatesAroundThem() async {
        harness.invites.candidatesResult = .success([marta, ayse])
        let viewModel = harness.makeInvitePeopleViewModel(for: group)
        #expect(viewModel.content == .loading && !viewModel.showsSearch)

        await viewModel.load()

        #expect(viewModel.content == .people && viewModel.showsSearch && viewModel.visible == [marta, ayse])
        #expect(harness.invites.candidateRequests == ["g"] && !viewModel.isLoading)
        #expect(await openSheet([]).content == .nobody)
    }

    @Test func aFailedLoadShowsTheFailedStateAndThePopup() async {
        harness.invites.candidatesResult = .failure(.inviteUnavailable)
        let viewModel = harness.makeInvitePeopleViewModel(for: group)

        await viewModel.load()

        #expect(viewModel.content == .failed && harness.presentedError == .inviteUnavailable)
        #expect(harness.logs(.error).count == 1)
    }

    @Test func theQueryNarrowsByNameWhateverTheCaseAndKeepsEveryoneWhenBlank() async {
        let viewModel = await openSheet([marta, ayse, noor])

        viewModel.query = "MAR"
        #expect(viewModel.visible == [marta] && viewModel.content == .people)
        viewModel.query = "ays"
        #expect(viewModel.visible == [ayse], "diacritics do not count")
        viewModel.query = "zzz"
        #expect(viewModel.visible.isEmpty && viewModel.content == .noMatches)
        viewModel.query = "  "
        #expect(viewModel.visible.count == 3)
    }

    @Test func invitingFlipsTheRowInPlaceAndLogsIt() async {
        let viewModel = await openSheet([marta, ayse])

        await viewModel.invite(marta)

        #expect(harness.invites.sentInvites == [FakeInviteRepository.SentInviteRequest(groupID: "g", userID: "u-2")])
        #expect(viewModel.candidates.map(\.isInvited) == [true, false] && !viewModel.isSending(marta))
        #expect(harness.logs(.info).contains("Invite sent to u-2 for group g") && harness.presentedError == nil)
    }

    @Test func anInvitedRowAndAStrangerSendNothing() async {
        let viewModel = await openSheet([noor])

        await viewModel.invite(noor)
        await viewModel.invite(marta)

        #expect(harness.invites.sentInvites.isEmpty)
    }

    /// One invite per row at a time: a second tap while the first is out is dropped.
    @Test func aSecondTapWhileTheInviteIsOutIsDropped() async {
        let viewModel = await openSheet([marta])
        harness.invites.holdsRequests = true

        let first = Task { await viewModel.invite(marta) }
        await settle(until: { harness.invites.sentInvites.count == 1 })
        #expect(viewModel.isSending(marta))
        await viewModel.invite(marta)
        harness.invites.releaseRequests()
        await first.value

        #expect(harness.invites.sentInvites.count == 1 && viewModel.candidates.first?.isInvited == true)
    }

    @Test func aLostRaceIsRepeatedOnceAndASecondOneIsShown() async {
        let viewModel = await openSheet([marta, ayse])
        harness.invites.transientInviteErrors = [.tryAgain]

        await viewModel.invite(marta)
        #expect(harness.invites.sentInvites.count == 2 && viewModel.candidates[0].isInvited && harness.presentedError == nil)
        #expect(harness.logs(.info).contains("Invite to u-2 for group g lost a race; retrying once"))

        harness.invites.transientInviteErrors = [.tryAgain, .tryAgain]
        await viewModel.invite(ayse)
        #expect(harness.invites.sentInvites.count == 4 && !viewModel.candidates[1].isInvited)
        #expect(harness.presentedError == .tryAgain)
    }

    @Test func alreadyAMemberIsReportedAndTheRowStaysOpen() async {
        let viewModel = await openSheet([marta])
        harness.invites.inviteResult = .failure(.alreadyMember)

        await viewModel.invite(marta)

        #expect(harness.presentedError == .alreadyMember && viewModel.candidates.first?.isInvited == false)
        #expect(harness.logs(.error) == ["Invite to u-2 for group g failed: alreadyMember"])
    }

    @Test func aTermsRefusalRaisesTheTermsSheet() async {
        let viewModel = await openSheet([marta])
        harness.invites.inviteResult = .failure(.termsRequired)

        await viewModel.invite(marta)

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func captionsNameWhatIsShared() {
        #expect(marta.caption == "In Kreuzberg Kickers")
        #expect(ayse.caption == "Played Sunset 5-a-side")
        #expect(marta.markingInvited().isInvited && marta.id == "u-2")
    }
}
