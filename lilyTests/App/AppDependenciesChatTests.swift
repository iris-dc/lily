import Foundation
import Testing
@testable import lily

/// The chat and realtime wiring per launch argument; the main suite is at its type-body limit.
@MainActor
struct AppDependenciesChatTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "lily.tests.dependencies.chat.\(UUID().uuidString)")!
    }

    @Test func mockEventsSelectTheInMemoryChatAndBusAndTheDefaultTheRemoteOnes() async {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeDefaults())
        #expect(mocked.chatRepository is MockChatRepository)
        #expect((mocked.chatRepository as? MockChatRepository)?.autoReplies == false)
        #expect(mocked.realtime.transport is MockRealtimeTransport)
        #expect(mocked.realtime.endpointProvider is FixedRealtimeEndpointProvider)
        #expect(await mocked.realtime.endpointProvider.endpoint() == AppConfig.Realtime.mockEndpoint)

        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeDefaults())
        #expect(remote.chatRepository is RemoteChatRepository)
        #expect(remote.realtime.transport is NoRealtimeTransport)
        #expect(remote.realtime.endpointProvider is RemoteRealtimeEndpointProvider)
        #expect(await remote.realtime.endpointProvider.endpoint() == nil, "no endpoint until /api/me or the argument names one")
    }

    @Test func realtimeEndpointLaunchArgumentOverridesDiscovery() async {
        let arguments = [AppConfig.LaunchArguments.realtimeEndpoint, "https://abc.appsync-realtime-api.eu-central-1.amazonaws.com/event"]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeDefaults())

        #expect(await dependencies.realtime.endpointProvider.endpoint() == URL(string: arguments[1]))

        let logger = SpyLogger()
        #expect(AppDependencies.realtimeEndpoint(from: [arguments[0], "not a url"], logger: logger) == nil)
        #expect(logger.messages(in: .network, at: .warning).count == 1)
        #expect(!logger.entries.contains { $0.message.contains("not a url") }, "the value is not logged")
    }

    @Test func mockChatRepliesLaunchArgumentTurnsOnTheAutoReply() {
        let arguments = [AppConfig.LaunchArguments.mockEvents, AppConfig.LaunchArguments.mockChatReplies]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeDefaults())
        #expect((dependencies.chatRepository as? MockChatRepository)?.autoReplies == true)
    }

    @Test func chatCollaboratorsAreSharedInstances() {
        let dependencies = AppDependencies.makeMock()
        #expect(dependencies.realtime === dependencies.groups.realtime)
        #expect(dependencies.chatHistory === dependencies.groups.chatHistory)
        #expect(dependencies.unreadCenter === dependencies.groups.unreadCenter)
        #expect(dependencies.realtime.cache === dependencies.chatHistory)
        #expect(dependencies.realtime.store === dependencies.myGroups)
    }

    @Test func chatStateClearsOnSignOut() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.realtime.setDesired(active: true, user: dependencies.sessionController.state.user)
        dependencies.chatHistory.store(ChatRoomState(groupID: "g", channelEpoch: 1), for: "g")
        dependencies.unreadCenter.markUnread(groupID: "g")
        #expect(dependencies.realtime.state == .connected)

        await dependencies.sessionController.signOut()
        await settle(until: { dependencies.realtime.state == .disconnected })

        #expect(dependencies.chatHistory.cachedGroupIDs.isEmpty && dependencies.unreadCenter.unreadGroupIDs.isEmpty)
        #expect(dependencies.realtime.subscribedRooms.isEmpty)
    }

    /// The mock run end to end: Mine feeds the rooms and the unread set, a chat opens on fixtures, a send echoes back.
    @Test func theMockChatWorksThroughTheFactories() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.realtime.setDesired(active: true, user: dependencies.sessionController.state.user)
        dependencies.myGroupsDidChange()
        #expect(dependencies.unreadCenter.unreadGroupIDs == [MockGroupFixtures.kickersID])
        #expect(dependencies.realtime.subscribedRooms.count == 3)

        let kickers = try #require(dependencies.myGroups.groups.first { $0.id == MockGroupFixtures.kickersID })
        let viewModel = dependencies.makeChatViewModel(for: kickers)
        await viewModel.appear()
        #expect(viewModel.rows.count > AppConfig.Chat.mockMessagesPerRoom && dependencies.unreadCenter.unreadGroupIDs.isEmpty)

        viewModel.draft.text = "hello"
        await viewModel.send()
        #expect(viewModel.pending.isEmpty && viewModel.room.messages.last?.text == "hello")
        try await Task.sleep(for: AppConfig.Chat.mockEchoDelay * 2)
        #expect(viewModel.room.messages.filter { $0.text == "hello" }.count == 1, "the echo is deduplicated")
        await viewModel.cancel()
    }
}
