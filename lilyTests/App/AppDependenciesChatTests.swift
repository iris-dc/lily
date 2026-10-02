import Foundation
import Testing
@testable import lily

/// The chat and realtime wiring per launch argument; the main suite is at its type-body limit. The mock echo runs on
/// the real clock, so the end-to-end case waits for it on a probe; the time limit keeps a lost echo from hanging.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppDependenciesChatTests {
    @Test func mockEventsSelectTheInMemoryChatAndBusAndTheDefaultTheRemoteOnes() async {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.chatRepository is MockChatRepository)
        #expect((mocked.chatRepository as? MockChatRepository)?.autoReplies == false)
        #expect(mocked.realtime.transport is MockRealtimeTransport)
        #expect(mocked.realtime.endpointProvider is FixedRealtimeEndpointProvider)
        #expect(await mocked.realtime.endpointProvider.endpoint() == AppConfig.Realtime.mockEndpoint)

        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.chatRepository is RemoteChatRepository)
        #expect(remote.realtime.transport is NoRealtimeTransport)
        #expect(remote.realtime.endpointProvider is RemoteRealtimeEndpointProvider)
        #expect(await remote.realtime.endpointProvider.endpoint() == nil, "no endpoint until /api/me or the argument names one")
    }

    @Test func realtimeEndpointLaunchArgumentOverridesDiscovery() async {
        let arguments = [AppConfig.LaunchArguments.realtimeEndpoint, "https://abc.appsync-realtime-api.eu-central-1.amazonaws.com/event"]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())

        #expect(await dependencies.realtime.endpointProvider.endpoint() == URL(string: arguments[1]))

        let logger = SpyLogger()
        #expect(AppDependencies.realtimeEndpoint(from: [arguments[0], "not a url"], logger: logger) == nil)
        #expect(logger.messages(in: .network, at: .warning).count == 1)
        #expect(!logger.entries.contains { $0.message.contains("not a url") }, "the value is not logged")
    }

    @Test func mockChatRepliesLaunchArgumentTurnsOnTheAutoReply() {
        let arguments = [AppConfig.LaunchArguments.mockEvents, AppConfig.LaunchArguments.mockChatReplies]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())
        #expect((dependencies.chatRepository as? MockChatRepository)?.autoReplies == true)
    }

    /// The attachment collaborators follow the data layer: the mock store's uploader with mock events, the real
    /// preparer unless the mock picker is asked for, the bucket uploader and the disk cache otherwise.
    @Test func attachmentCollaboratorsFollowTheLaunchArguments() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.groups.attachments.uploader is MockAttachmentUploader)
        #expect(mocked.groups.attachments.preparer is DeviceMediaPreparer)

        let picker = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents,
                                                             AppConfig.LaunchArguments.mockAttachmentPicker],
                                                 defaults: makeTestDefaults())
        #expect(picker.groups.attachments.preparer is MockMediaPreparer)
        #expect(picker.makeAttachmentComposer(for: SportGroup.fixture(id: "g")).picksWithoutPicker)

        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.groups.attachments.uploader is URLSessionAttachmentUploader)
        #expect(remote.groups.attachments.preparer is DeviceMediaPreparer)
        #expect(!remote.makeAttachmentComposer(for: SportGroup.fixture(id: "g")).picksWithoutPicker)
        #expect(remote.groups.sessionObservers.contains { $0 === remote.groups.attachments.cache })
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
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.realtime.setDesired(active: true, user: dependencies.sessionController.state.user)
        dependencies.chatHistory.store(ChatRoomState(groupID: "g", channelEpoch: 1), for: "g")
        dependencies.unreadCenter.markUnread(groupID: "g", messageID: "m1")
        #expect(dependencies.realtime.state == .connected)

        await dependencies.sessionController.signOut()
        await settle(until: { dependencies.realtime.state == .disconnected })

        #expect(dependencies.chatHistory.cachedGroupIDs.isEmpty && dependencies.unreadCenter.unreadGroupIDs.isEmpty)
        #expect(dependencies.realtime.subscribedRooms.isEmpty)
    }

    /// The mock run end to end: Mine feeds the rooms and the unread set, a chat opens on fixtures and reads its room
    /// for good (the next Mine load shows it read), a send echoes back.
    @Test func theMockChatWorksThroughTheFactories() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.realtime.setDesired(active: true, user: dependencies.sessionController.state.user)
        dependencies.myGroupsDidLoad()
        dependencies.myGroupsDidChange()
        #expect(dependencies.unreadCenter.unreadGroupIDs == [MockGroupFixtures.kickersID, MockGroupFixtures.martaConversationID])
        #expect(dependencies.realtime.subscribedRooms.count == 4, "the three groups and the conversation")

        let kickers = try #require(dependencies.myGroups.groups.first { $0.id == MockGroupFixtures.kickersID })
        let viewModel = dependencies.makeChatViewModel(for: kickers)
        await viewModel.appear()
        #expect(viewModel.rows.count > AppConfig.Chat.mockMessagesPerRoom)
        #expect(dependencies.unreadCenter.unreadGroupIDs == [MockGroupFixtures.martaConversationID],
                "the conversation is still unread")

        await dependencies.myGroups.reload()
        dependencies.myGroupsDidLoad()
        #expect(dependencies.unreadCenter.unreadGroupIDs == [MockGroupFixtures.martaConversationID],
                "a load after reading the room brings no dot back")
        #expect(dependencies.myGroups.groups.first { $0.id == MockGroupFixtures.kickersID }?.hasUnread == false)

        // The controller applies an envelope to the room cache before it hands it to its consumers, so once the probe
        // has the echo, the cache has already seen it.
        let echoes = dependencies.realtime.envelopes(for: kickers.id)
        let echo = Task { await echoes.first { _ in true } }
        viewModel.draft.text = "hello"
        await viewModel.send()
        #expect(viewModel.pending.isEmpty && viewModel.room.messages.last?.text == "hello")
        let sent = try #require(viewModel.room.messages.last)
        #expect(await echo.value == .message(sent), "the send echoes back over the mock bus")
        #expect(viewModel.room.messages.filter { $0.text == "hello" }.count == 1, "the echo is deduplicated")
        await viewModel.cancel()
    }
}
