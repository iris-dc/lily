import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct InvitePreviewViewModelTests {
    private let harness = GroupHarness()
    private let joined = SportGroup.fixture(id: "g3", name: "Climbing Buddies", visibility: .private, role: .member)

    private func makeViewModel() throws -> InvitePreviewViewModel {
        InvitePreviewViewModel(code: try #require(InviteCode(AppConfig.Groups.mockInviteCode)),
                               invites: harness.invites,
                               groups: harness.repository,
                               identity: harness.identity,
                               store: harness.store,
                               navigation: harness.navigation,
                               reporter: harness.reporter,
                               logger: harness.logger,
                               tryAgainDelay: .zero,
                               onJoined: harness.sink.record)
    }

    /// A loaded preview with the redeem scripted to succeed.
    private func makeLoadedViewModel() async throws -> InvitePreviewViewModel {
        harness.invites.previewResult = .success(.fixture())
        harness.invites.redeemResult = .success(joined)
        let viewModel = try makeViewModel()
        await viewModel.load()
        return viewModel
    }

    @Test func loadShowsThePreviewAndNeverLogsTheCode() async throws {
        harness.invites.previewResult = .success(.fixture())
        let viewModel = try makeViewModel()

        await viewModel.load()

        #expect(viewModel.groupName == "Climbing Buddies" && !viewModel.loadFailed && viewModel.canJoin)
        #expect(harness.logs(.info) == ["Invite previewed for group g3"])
        #expect(!harness.logs().joined().contains("KRZB"))
    }

    /// Offline, or a preview the backend could not answer (`.inviteUnavailable`, the remote fallback for a 500 or an
    /// unreadable body): no verdict on the code, so the popup shows and Try again stays.
    @Test(arguments: [AppError.network, .inviteUnavailable])
    func aTransientFailureIsReportedAndCanBeRetried(error: AppError) async throws {
        harness.invites.previewResult = .failure(error)
        let viewModel = try makeViewModel()

        await viewModel.load()

        #expect(viewModel.loadFailed && viewModel.canRetry && !viewModel.canJoin && viewModel.refusal == nil)
        #expect(harness.presentedError == error)
    }

    /// An invalid or expired code is answered in the sheet itself; a popup on top would say the same thing twice.
    @Test(arguments: [AppError.inviteInvalid, .inviteExpired])
    func aRefusedCodeIsShownInlineWithoutAPopup(error: AppError) async throws {
        harness.invites.previewResult = .failure(error)
        let viewModel = try makeViewModel()

        await viewModel.load()

        #expect(viewModel.refusal == error && viewModel.loadFailed && !viewModel.canRetry && !viewModel.canJoin)
        #expect(harness.presentedError == nil)
    }

    @Test func guestsMustSignInBeforeJoining() async throws {
        harness.identity.currentUserID = nil
        let viewModel = try await makeLoadedViewModel()
        #expect(viewModel.needsSignIn)

        await viewModel.join()

        #expect(harness.invites.redeemedCodes.isEmpty && viewModel.joinedGroup == nil)

        harness.identity.currentUserID = TestFixtures.user.id
        await viewModel.join()
        #expect(viewModel.joinedGroup?.id == "g3")
    }

    @Test func joinRedeemsAddsToMineOpensTheChatAndHandsOn() async throws {
        let viewModel = try await makeLoadedViewModel()

        await viewModel.join()

        #expect(viewModel.joinedGroup?.id == "g3" && !viewModel.canJoin)
        #expect(harness.store.groups.map(\.id) == ["g3"])
        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1)
        #expect(harness.changed.map(\.id) == ["g3"])
        #expect(harness.invites.redeemedCodes.map(\.value) == [AppConfig.Groups.mockInviteCode])
        #expect(harness.logs(.info).contains("Invite redeemed for group g3"))
    }

    @Test func tryAgainIsRepeatedOnce() async throws {
        let viewModel = try await makeLoadedViewModel()
        harness.invites.transientRedeemErrors = [.tryAgain]

        await viewModel.join()

        #expect(harness.invites.redeemedCodes.count == 2)
        #expect(viewModel.joinedGroup != nil && harness.presentedError == nil)
        #expect(harness.logs(.info).contains("Invite redeem lost a race; retrying once"))
    }

    @Test func anUnknownOutcomeThatLandedIsAccepted() async throws {
        let viewModel = try await makeLoadedViewModel()
        harness.invites.redeemResult = .failure(.network)
        harness.repository.result = .success([joined])

        await viewModel.join()

        #expect(viewModel.joinedGroup?.id == "g3" && harness.presentedError == nil)
        #expect(harness.repository.fetchedGroupIDs == ["g3"])
        #expect(harness.logs(.info).contains { $0.hasPrefix("Invite redeem landed for group g3") })
    }

    @Test func anUnknownOutcomeThatDidNotLandIsReported() async throws {
        let viewModel = try await makeLoadedViewModel()
        harness.invites.redeemResult = .failure(.network)
        harness.repository.result = .success([])

        await viewModel.join()

        #expect(viewModel.joinedGroup == nil && harness.presentedError == .network)
        #expect(harness.logs(.warning).contains { $0.hasPrefix("Could not check whether the redeem landed") })
    }

    @Test func aRefusalIsReportedWithoutALookup() async throws {
        let viewModel = try await makeLoadedViewModel()
        harness.invites.redeemResult = .failure(.inviteInvalid)

        await viewModel.join()

        #expect(harness.presentedError == .inviteInvalid && viewModel.joinedGroup == nil)
        #expect(harness.repository.fetchedGroupIDs.isEmpty && harness.store.groups.isEmpty)
    }

    @Test func termsRequiredRaisesTheTermsSheet() async throws {
        let viewModel = try await makeLoadedViewModel()
        harness.invites.redeemResult = .failure(.termsRequired)

        await viewModel.join()

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func joinBeforeThePreviewDoesNothing() async throws {
        let viewModel = try makeViewModel()

        await viewModel.join()

        #expect(harness.invites.redeemedCodes.isEmpty && !viewModel.canJoin)
    }
}
