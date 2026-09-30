import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct UserProfileViewModelTests {
    private let harness = GroupHarness()
    private let users = FakeUserRepository()

    private func makeViewModel(destination: UserProfileDestination = .fixture()) -> UserProfileViewModel {
        UserProfileViewModel(destination: destination,
                             repository: users,
                             identity: harness.identity,
                             myGroups: harness.store,
                             navigation: harness.navigation,
                             reporter: harness.reporter,
                             logger: harness.logger,
                             tryAgainDelay: .zero)
    }

    @Test func loadShowsTheProfileAndLogsTheOpenOnce() async {
        let viewModel = makeViewModel()
        #expect(viewModel.state == .loading && viewModel.displayName == "Marta", "the row's name shows until the profile answers")

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.state == .loaded(.fixture()))
        #expect(viewModel.profile?.sharedGroups.map(\.name) == ["Kreuzberg Kickers"])
        #expect(users.requestedProfileIDs == ["u-2", "u-2"])
        #expect(harness.logs(.info).filter { $0 == "Profile u-2 opened" }.count == 1)
    }

    /// The profile's current name replaces the one the row carried.
    @Test func theProfilesNameWinsOnceLoaded() async {
        users.profileResult = .success(.fixture(displayName: "Marta K."))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.displayName == "Marta K.")
    }

    @Test func aFailedLoadReachesThePopupAndOffersARetry() async {
        users.profileResult = .failure(.profileUnavailable)
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .failed)
        #expect(harness.presentedError == .profileUnavailable)
        #expect(harness.logs(.error).count == 1)
    }

    @Test func selfHidesTheMessageButtonAndNeverStartsAConversation() async {
        let viewModel = makeViewModel(destination: .fixture(userId: TestFixtures.user.id, displayName: "Test Person"))

        #expect(viewModel.isSelf && !viewModel.canMessage)
        await viewModel.message()

        #expect(users.conversationRequests.isEmpty)
        #expect(harness.navigation.chatPath.isEmpty)
    }

    @Test func guestsCannotMessage() async {
        harness.identity.currentUserID = nil
        let viewModel = makeViewModel()

        #expect(!viewModel.canMessage && !viewModel.isSelf)
        await viewModel.message()

        #expect(users.conversationRequests.isEmpty)
    }

    /// From the conversation itself "Message" would push the same chat again, so the profile its info button opens
    /// offers none, as the group detail reached from a chat hides "Open chat".
    @Test func theProfileReachedFromTheConversationOffersNoMessage() async {
        let viewModel = makeViewModel(destination: .fixture(context: .fromChat))

        #expect(!viewModel.canMessage && !viewModel.isSelf)
        await viewModel.message()

        #expect(users.conversationRequests.isEmpty && harness.navigation.chatPath.isEmpty)
    }

    /// The view's task restarts on the way back from a pushed group: the profile on screen stays while the reload runs
    /// and when it fails, and the popup says why.
    @Test func aReloadKeepsTheLoadedProfile() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        users.holdsRequests = true
        let reload = Task { await viewModel.load() }
        await settle(until: { users.requestedProfileIDs.count == 2 })
        #expect(viewModel.state == .loaded(.fixture()), "no spinner over a profile already on screen")

        users.profileResult = .failure(.profileUnavailable)
        users.releaseRequests()
        await reload.value

        #expect(viewModel.state == .loaded(.fixture()) && harness.presentedError == .profileUnavailable)
    }

    /// The conversation lands in Mine before its chat opens, so the Chats tab lists it on the way back.
    @Test func messageAddsTheConversationToMineAndOpensItsChat() async {
        let conversation = SportGroup.conversationFixture()
        let viewModel = makeViewModel()

        await viewModel.message()

        #expect(users.conversationRequests == ["u-2"])
        #expect(harness.store.groups == [conversation] && harness.store.communities.isEmpty, "a room, not one of Home's groups")
        #expect(harness.navigation.selectedTab == .chat && harness.navigation.chatPath.count == 1)
        #expect(harness.logs(.info).contains("Conversation \(conversation.id) started with u-2"))
        #expect(!viewModel.isStartingConversation && harness.presentedError == nil)
    }

    @Test func aLostRaceIsRepeatedOnceWithoutAPopup() async {
        users.transientConversationErrors = [.tryAgain]
        let viewModel = makeViewModel()

        await viewModel.message()

        #expect(users.conversationRequests == ["u-2", "u-2"])
        #expect(harness.navigation.chatPath.count == 1 && harness.presentedError == nil)
        #expect(harness.logs(.info).contains { $0.contains("retrying once") })
    }

    @Test func aFailedStartReachesThePopupAndOpensNothing() async {
        users.conversationResult = .failure(.conversationLimit)
        let viewModel = makeViewModel()

        await viewModel.message()

        #expect(harness.presentedError == .conversationLimit)
        #expect(harness.store.groups.isEmpty && harness.navigation.chatPath.isEmpty)
        #expect(harness.logs(.error).contains { $0.contains("Starting a conversation with u-2 failed") })
    }

    /// A `TERMS_REQUIRED` on the start raises the terms sheet like every groups write.
    @Test func termsRequiredRaisesTheTermsSheet() async {
        users.conversationResult = .failure(.termsRequired)

        await makeViewModel().message()

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func aSecondTapWhileOneRunsIsDropped() async {
        users.holdsRequests = true
        let viewModel = makeViewModel()

        let first = Task { await viewModel.message() }
        await settle(until: { viewModel.isStartingConversation })
        await viewModel.message()
        #expect(users.conversationRequests.count == 1)

        users.releaseRequests()
        await first.value
        #expect(!viewModel.isStartingConversation && harness.navigation.chatPath.count == 1)
    }

    @Test func cancellationIsQuiet() async {
        users.thrownError = CancellationError()
        let viewModel = makeViewModel()

        await viewModel.load()
        await viewModel.message()

        #expect(viewModel.state == .loading && harness.presentedError == nil)
        #expect(harness.logs(.error).isEmpty)
    }
}
