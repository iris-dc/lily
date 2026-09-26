import Foundation
import Testing
@testable import lily

@MainActor
struct InviteViewModelTests {
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let harness = GroupHarness()
    private let viewModel: InviteViewModel

    init() {
        viewModel = InviteViewModel(group: .fixture(id: "g", name: "Kreuzberg Kickers", role: .admin),
                                    repository: harness.invites,
                                    reporter: harness.reporter,
                                    recorder: harness.recorder,
                                    pasteboard: harness.pasteboard,
                                    logger: harness.logger,
                                    now: { Self.now })
    }

    private var fixtureID: String { Invite.fixture().inviteId }

    @Test func startsFromTheDefaultOptionsWithNothingToShare() {
        #expect(viewModel.expiresInDays == AppConfig.Groups.inviteDefaultDays && viewModel.maxUses == 0)
        #expect(viewModel.options == InviteOptions())
        #expect(!viewModel.canShare && viewModel.shareURL == nil && viewModel.formattedCode == nil)
        #expect(viewModel.shareText == "Join Kreuzberg Kickers on lily")
    }

    @Test func createSendsTheOptionsAndOffersTheLinkAndCode() async {
        viewModel.maxUses = 10
        viewModel.expiresInDays = 1

        await viewModel.create()
        await viewModel.create()

        #expect(harness.invites.createdOptions.map(\.groupID) == ["g"], "one invite per set of options")
        #expect(harness.invites.createdOptions.first?.options == InviteOptions(maxUses: 10, expiresInDays: 1))
        #expect(viewModel.canShare)
        #expect(viewModel.shareURL == Invite.fixture().url)
        #expect(viewModel.formattedCode == "KRZB-7K3M-QX9P")
        #expect(harness.logs(.info) == ["Invite \(fixtureID) created for group g"])
    }

    /// What is shared must be what the options say, so a changed option drops the invite already made and revokes
    /// it on the backend, where it would otherwise count against the group's active invites.
    @Test func changingAnOptionDropsAndRevokesTheInvite() async {
        await viewModel.create()
        viewModel.copyCode()

        viewModel.maxUses = 1

        #expect(viewModel.invite == nil && !viewModel.codeCopied && !viewModel.wasShared && !viewModel.canShare)
        await settle(until: { harness.invites.revocations.count == 1 })
        #expect(harness.invites.revocations.first?.groupID == "g")
        #expect(harness.invites.revocations.first?.inviteID == fixtureID)
        #expect(harness.logs(.info).contains("Invite \(fixtureID) revoked for group g"))
    }

    /// A chip tapped while the first create is still out must not leave the sheet without an invite: the create for
    /// the new options runs, and the late answer for the old ones is revoked instead of shown.
    @Test func changingAnOptionDuringTheFirstCreateStillEndsWithAnInvite() async {
        harness.invites.holdsRequests = true
        let first = Task { await viewModel.create() }
        await settle(until: { harness.invites.createdOptions.count == 1 })

        viewModel.maxUses = 1
        harness.invites.holdsRequests = false
        let second = Task { await viewModel.create() }
        await settle(until: { harness.invites.createdOptions.count == 2 })
        harness.invites.releaseRequests()
        await first.value
        await second.value

        #expect(harness.invites.createdOptions.map(\.options.maxUses) == [0, 1])
        #expect(viewModel.invite != nil && viewModel.canShare && !viewModel.isCreating)
        await settle(until: { harness.invites.revocations.count == 1 })
    }

    @Test func closingWithoutSharingRevokesTheInvite() async {
        await viewModel.create()

        viewModel.close()

        await settle(until: { harness.invites.revocations.count == 1 })
        #expect(harness.invites.revocations.first?.inviteID == fixtureID)
    }

    /// `ShareLink` never says whether the link was sent, so an opened share sheet counts as shared and the invite stays.
    @Test func closingAfterSharingKeepsTheInvite() async {
        await viewModel.create()
        viewModel.recordShared()

        viewModel.close()
        for _ in 0..<10 { await Task.yield() }

        #expect(viewModel.wasShared && harness.invites.revocations.isEmpty)
    }

    /// SwiftUI can deliver `onDisappear` more than once; the invite is gone after the first close, so nothing repeats.
    @Test func closingTwiceRevokesOnce() async {
        await viewModel.create()

        viewModel.close()
        viewModel.close()

        await settle(until: { harness.invites.revocations.count == 1 })
        for _ in 0..<10 { await Task.yield() }
        #expect(harness.invites.revocations.count == 1)
        #expect(viewModel.invite == nil && !viewModel.canShare)
    }

    @Test func aFailedRevocationIsAWarningNotAPopup() async {
        await viewModel.create()
        harness.invites.revokeError = .groupActionFailed

        viewModel.maxUses = 1

        await settle(until: { harness.logs(.warning).count == 1 })
        #expect(harness.logs(.warning).first?.hasPrefix("Invite \(fixtureID) revocation failed for group g") == true)
        #expect(harness.presentedError == nil)
    }

    @Test func copyCodePutsTheGroupedCodeOnThePasteboardAndRecordsAShare() async {
        await viewModel.create()

        viewModel.copyCode()

        #expect(harness.pasteboard.copied == ["KRZB-7K3M-QX9P"])
        #expect(viewModel.codeCopied && viewModel.wasShared)
        #expect(harness.recorder.kinds == [.inviteShared])
        #expect(harness.recorder.interactions.first?.groupId == "g")
        #expect(!harness.logs().joined().contains("KRZB"), "the code never reaches a log line")
    }

    @Test func copyWithoutAnInviteDoesNothing() {
        viewModel.copyCode()

        #expect(harness.pasteboard.copied.isEmpty && !viewModel.codeCopied && harness.recorder.kinds.isEmpty)
    }

    @Test func recordSharedReportsTheGroupOnly() {
        viewModel.recordShared()

        let interaction = harness.recorder.interactions.first
        #expect(interaction?.kind == .inviteShared && interaction?.groupId == "g" && interaction?.occurredAt == Self.now)
        #expect(interaction?.groupVisibility == nil)
    }

    @Test func aFailureReachesThePopup() async {
        harness.invites.createResult = .failure(.insufficientRole)

        await viewModel.create()

        #expect(viewModel.invite == nil && !viewModel.canShare)
        #expect(harness.presentedError == .insufficientRole)
        #expect(harness.logs(.error).count == 1)
    }
}
