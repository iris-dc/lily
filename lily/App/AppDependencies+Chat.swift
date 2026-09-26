import Foundation

extension AppDependencies {
    var chatRepository: any ChatRepository { groups.chatRepository }
    var chatHistory: InMemoryChatHistoryCache { groups.chatHistory }
    var unreadCenter: UnreadCenter { groups.unreadCenter }
    var realtime: RealtimeSessionController { groups.realtime }

    /// The `-realtime-endpoint` value when it is a URL with a scheme and a host; `nil` leaves discovery to `GET /api/me`.
    static func realtimeEndpoint(from arguments: [String], logger: any Logging) -> URL? {
        guard let url = url(following: AppConfig.LaunchArguments.realtimeEndpoint, in: arguments, logger: logger) else {
            return nil
        }
        logger.info(.chat, "Realtime endpoint overridden by launch argument")
        return url
    }

    /// Mine changed (a load, a join, a leave): the room subscriptions follow it.
    func myGroupsDidChange() {
        realtime.syncRooms()
    }

    /// Mine was loaded: the unread set merges the snapshot. A local change never drives it (see `MyGroupsStore.loadVersion`).
    func myGroupsDidLoad() {
        unreadCenter.apply(groups: myGroups.groups)
    }

    func makeChatViewModel(for group: SportGroup) -> ChatViewModel {
        ChatViewModel(group: group,
                      repository: chatRepository,
                      groups: groupRepository,
                      events: eventRepository,
                      eventChanges: eventChanges,
                      pasteboard: groups.pasteboard,
                      cache: chatHistory,
                      realtime: realtime,
                      catchUp: groups.catchUp,
                      unread: unreadCenter,
                      identity: identity,
                      reporter: groups.errorReporter,
                      recorder: interactionRecorder,
                      logger: logger)
    }
}
