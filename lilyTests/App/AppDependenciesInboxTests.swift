import Foundation
import SwiftUI
import Testing
@testable import lily

/// The inbox wiring per launch argument and the mock inbox end to end; the main suite is at its type-body limit.
@MainActor
struct AppDependenciesInboxTests {
    private func makeSignedInMock() async -> AppDependencies {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        return dependencies
    }

    @Test func mockEventsSelectTheMockInboxAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.inboxRepository is MockInboxRepository)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.inboxRepository is RemoteInboxRepository)
        #expect(AppDependencies.makeMock().inboxRepository is MockInboxRepository)
    }

    /// The tab badge, the Chats row, the realtime controller and the inbox screen must all read one store.
    @Test func inboxCollaboratorsAreSharedInstances() {
        let dependencies = AppDependencies.makeMock()
        #expect(dependencies.inbox === dependencies.groups.inbox)
        #expect(dependencies.realtime.inbox === dependencies.inbox)
    }

    @Test func theInboxClearsOnSignOut() async {
        let dependencies = await makeSignedInMock()
        await dependencies.inbox.reload()
        #expect(dependencies.inbox.items.count == 4 && dependencies.inbox.hasUnread)

        await dependencies.sessionController.signOut()

        #expect(dependencies.inbox.items.isEmpty && !dependencies.inbox.hasUnread)
    }

    /// The mock run end to end: opening the inbox marks it read, accepting the invite puts Climbing Buddies into Mine
    /// and opens its chat on the Chats tab, and the reminder opens its game on the same stack.
    @Test func theMockInboxWorksThroughTheFactories() async throws {
        let dependencies = await makeSignedInMock()
        let viewModel = dependencies.makeInboxViewModel()

        await viewModel.appear()
        #expect(dependencies.inbox.items.count == 4 && !dependencies.inbox.hasUnread, "opening the inbox marks it read")
        let cards = viewModel.rows.filter { if case .item = $0 { true } else { false } }
        #expect(cards.count == 4, "every fixture is a kind this build draws")

        let invite = try #require(dependencies.inbox.items.first { $0.invite != nil })
        await viewModel.accept(invite)
        #expect(dependencies.myGroups.groups.contains { $0.id == MockGroupFixtures.climbingID })
        #expect(dependencies.navigation.selectedTab == .chat && dependencies.navigation.chatPath.count == 1)
        #expect(dependencies.inbox.items.first { $0.id == invite.id }?.invite?.status == .accepted)
        #expect(dependencies.errorCenter.current == nil)

        let reminder = try #require(dependencies.inbox.items.first { $0.reminder != nil })
        await viewModel.openEvent(for: reminder)
        #expect(dependencies.navigation.chatPath.count == 2)
    }
}
