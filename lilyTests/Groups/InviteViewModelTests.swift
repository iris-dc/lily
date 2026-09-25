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
        #expect(harness.logs(.info) == ["Invite \(Invite.fixture().inviteId) created for group g"])
    }

    /// What is shared must be what the options say, so a changed option drops the invite already made.
    @Test func changingAnOptionDropsTheInvite() async {
        await viewModel.create()
        viewModel.copyCode()

        viewModel.maxUses = 1

        #expect(viewModel.invite == nil && !viewModel.codeCopied && !viewModel.canShare)
    }

    @Test func copyCodePutsTheGroupedCodeOnThePasteboardAndRecordsAShare() async {
        await viewModel.create()

        viewModel.copyCode()

        #expect(harness.pasteboard.copied == ["KRZB-7K3M-QX9P"])
        #expect(viewModel.codeCopied)
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
