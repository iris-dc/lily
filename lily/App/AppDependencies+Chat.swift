import Foundation

/// The collaborators of chat attachments, held as one value so `GroupDependencies` gains a single stored property: the
/// bytes on disk (keyed by id; the loader fills it, the composer seeds it with what was just sent), the loader over
/// the data layer's session, and the uploader and preparer the data layer chose (bucket or mock, pickers or the
/// bundled photo).
struct AttachmentDependencies {
    let cache: DiskAttachmentCache
    let loader: AttachmentLoader
    let uploader: any AttachmentUploader
    let preparer: any MediaPreparer

    init(repositories: GroupRepositories, logger: any Logging) {
        let cache = DiskAttachmentCache(logger: logger)
        self.cache = cache
        loader = AttachmentLoader(repository: repositories.chat,
                                  cache: cache,
                                  session: repositories.attachmentSession,
                                  logger: logger)
        uploader = repositories.attachmentUploader
        preparer = repositories.mediaPreparer
    }
}

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
                      me: me,
                      attachments: makeAttachmentComposer(for: group),
                      attachmentLoader: groups.attachments.loader,
                      identity: identity,
                      reporter: groups.errorReporter,
                      clearer: makeChatHistoryClearer(),
                      recorder: interactionRecorder,
                      logger: logger)
    }

    /// The pictures picked for one room's composer; its uploads go through the room's repository and the shared uploader.
    func makeAttachmentComposer(for group: SportGroup) -> AttachmentComposerModel {
        AttachmentComposerModel(groupID: group.id,
                                repository: chatRepository,
                                uploader: groups.attachments.uploader,
                                preparer: groups.attachments.preparer,
                                cache: groups.attachments.cache,
                                reporter: groups.errorReporter,
                                logger: logger)
    }

    /// Clears a room for the caller alone; the chat's menu and a Chats row's context menu both go through one.
    func makeChatHistoryClearer() -> ChatHistoryClearer {
        ChatHistoryClearer(repository: chatRepository,
                           cache: chatHistory,
                           myGroups: myGroups,
                           unread: unreadCenter,
                           reporter: groups.errorReporter,
                           logger: logger)
    }
}
