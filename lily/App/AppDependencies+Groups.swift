import Foundation

/// The repositories and the realtime transport of the groups feature, built together in `Repositories` so a mock run
/// stays in memory throughout. The endpoint provider is built once `MeStore` exists, because the real one reads it.
struct GroupRepositories {
    let groups: any GroupRepository
    let invites: any InviteRepository
    let me: any MeRepository
    let moderation: any ModerationRepository
    let chat: any ChatRepository
    let realtimeTransport: any RealtimeTransport
    let makeRealtimeEndpointProvider: @MainActor (MeStore) -> any RealtimeEndpointProvider

    /// The remote set over the app's one API client. The transport is `NoRealtimeTransport` until the AppSync client
    /// is added; the endpoint provider already discovers the endpoint, so that swap is one line here.
    static func remote(client: any APIClient, realtimeEndpoint: URL?, identity: any IdentityProvider) -> GroupRepositories {
        GroupRepositories(groups: RemoteGroupRepository(client: client, identity: identity),
                          invites: RemoteInviteRepository(client: client),
                          me: RemoteMeRepository(client: client),
                          moderation: RemoteModerationRepository(client: client),
                          chat: RemoteChatRepository(client: client),
                          realtimeTransport: NoRealtimeTransport(),
                          makeRealtimeEndpointProvider: { me in
                              RemoteRealtimeEndpointProvider(override: realtimeEndpoint, me: me)
                          })
    }

    /// The invite mock admits into the group mock's groups and the chat mock reads them, so the three share one
    /// instance; the chat mock echoes over the one in-memory bus the controller subscribes to.
    static func mock(identity: any IdentityProvider, logger: any Logging, autoReplies: Bool) -> GroupRepositories {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        let transport = MockRealtimeTransport(logger: logger)
        return GroupRepositories(groups: groups,
                                 invites: MockInviteRepository(groups: groups, identity: identity, logger: logger),
                                 me: MockMeRepository(identity: identity, logger: logger),
                                 moderation: MockModerationRepository(logger: logger),
                                 chat: MockChatRepository(groups: groups,
                                                          transport: transport,
                                                          identity: identity,
                                                          logger: logger,
                                                          autoReplies: autoReplies),
                                 realtimeTransport: transport,
                                 makeRealtimeEndpointProvider: { _ in
                                     FixedRealtimeEndpointProvider(url: AppConfig.Realtime.mockEndpoint)
                                 })
    }
}

/// The collaborators of groups, chat and moderation, held as one value so `AppDependencies` gains a single stored
/// property however many the feature needs.
struct GroupDependencies {
    let groupRepository: any GroupRepository
    let inviteRepository: any InviteRepository
    let meRepository: any MeRepository
    let moderationRepository: any ModerationRepository
    let chatRepository: any ChatRepository
    /// The one source of the caller's groups for every screen and store that needs them.
    let myGroups: MyGroupsStore
    let me: MeStore
    /// The rooms held in memory; the open chat and the realtime controller share it.
    let chatHistory: InMemoryChatHistoryCache
    let unreadCenter: UnreadCenter
    let catchUp: ChatCatchUp
    let realtime: RealtimeSessionController
    /// Every groups screen reports failures through it: the popup, plus `MeStore.noteTermsRequired()` on `TERMS_REQUIRED`.
    let errorReporter: GroupErrorReporter
    let pasteboard: any Pasteboard
    /// Invite links (and `-open-invite`) wait here until the root view can present the preview.
    let deepLinks: DeepLinkCenter
    let navigation = AppNavigation()
    /// Counts group changes made anywhere, as `AppDependencies.eventChanges` does for events.
    let groupChanges = ChangeTracker()

    init(repositories: GroupRepositories,
         identity: any IdentityProvider,
         tokenProvider: (any AuthTokenProvider)?,
         errorCenter: ErrorCenter,
         logger: any Logging,
         deepLinks: DeepLinkCenter,
         pasteboard: any Pasteboard = SystemPasteboard()) {
        groupRepository = repositories.groups
        inviteRepository = repositories.invites
        meRepository = repositories.me
        moderationRepository = repositories.moderation
        chatRepository = repositories.chat
        let myGroups = MyGroupsStore(repository: repositories.groups,
                                     identity: identity,
                                     changes: groupChanges,
                                     errorCenter: errorCenter,
                                     logger: logger)
        self.myGroups = myGroups
        let me = MeStore(repository: repositories.me, identity: identity, errorCenter: errorCenter, logger: logger)
        self.me = me
        errorReporter = GroupErrorReporter(errorCenter: errorCenter) { me.noteTermsRequired() }
        let chatHistory = InMemoryChatHistoryCache(logger: logger)
        self.chatHistory = chatHistory
        let unreadCenter = UnreadCenter()
        self.unreadCenter = unreadCenter
        let catchUp = ChatCatchUp(repository: repositories.chat, cache: chatHistory, logger: logger)
        self.catchUp = catchUp
        realtime = RealtimeSessionController(transport: repositories.realtimeTransport,
                                             endpointProvider: repositories.makeRealtimeEndpointProvider(me),
                                             tokenProvider: tokenProvider,
                                             identity: identity,
                                             store: myGroups,
                                             cache: chatHistory,
                                             catchUp: catchUp,
                                             unread: unreadCenter,
                                             groupChanges: groupChanges,
                                             groupRepository: repositories.groups,
                                             errorCenter: errorCenter,
                                             logger: logger)
        self.pasteboard = pasteboard
        self.deepLinks = deepLinks
    }

    /// Everything here that holds state for the signed-in user; `SessionController` tells them when the session ends.
    var sessionObservers: [any SessionObserver] { [myGroups, me, chatHistory, unreadCenter, realtime] }
}

extension AppDependencies {
    var groupRepository: any GroupRepository { groups.groupRepository }
    var inviteRepository: any InviteRepository { groups.inviteRepository }
    var meRepository: any MeRepository { groups.meRepository }
    var moderationRepository: any ModerationRepository { groups.moderationRepository }
    var myGroups: MyGroupsStore { groups.myGroups }
    var me: MeStore { groups.me }
    var navigation: AppNavigation { groups.navigation }
    var deepLinks: DeepLinkCenter { groups.deepLinks }
    var groupChanges: ChangeTracker { groups.groupChanges }

    func makeGroupListViewModel(scope: GroupListScope) -> GroupListViewModel {
        GroupListViewModel(scope: scope,
                           store: myGroups,
                           repository: groupRepository,
                           identity: identity,
                           errorCenter: errorCenter,
                           recorder: interactionRecorder,
                           logger: logger)
    }

    /// `onChange` receives the group as the backend answered it; the list behind the detail replaces its row.
    func makeGroupDetailViewModel(for group: SportGroup,
                                  context: GroupDetailContext,
                                  onChange: @escaping @MainActor (SportGroup) -> Void) -> GroupDetailViewModel {
        GroupDetailViewModel(group: group,
                             context: context,
                             repository: groupRepository,
                             identity: identity,
                             store: myGroups,
                             reporter: groups.errorReporter,
                             recorder: interactionRecorder,
                             logger: logger,
                             onChange: onChange)
    }

    func makeGroupLoaderViewModel(ref: EventGroupRef) -> GroupLoaderViewModel {
        GroupLoaderViewModel(ref: ref, repository: groupRepository, errorCenter: errorCenter, logger: logger)
    }

    func makeCreateGroupViewModel(onCreated: @escaping @MainActor (SportGroup) -> Void) -> CreateGroupViewModel {
        CreateGroupViewModel(repository: groupRepository,
                             store: myGroups,
                             reporter: groups.errorReporter,
                             logger: logger,
                             onCreated: onCreated)
    }

    func makeEditGroupViewModel(for group: SportGroup,
                                onChange: @escaping @MainActor (SportGroup) -> Void) -> EditGroupViewModel {
        EditGroupViewModel(group: group,
                           repository: groupRepository,
                           store: myGroups,
                           reporter: groups.errorReporter,
                           logger: logger,
                           onChange: onChange)
    }

    func makeMembersViewModel(for group: SportGroup,
                              onChange: @escaping @MainActor (SportGroup) -> Void) -> MembersViewModel {
        MembersViewModel(group: group,
                         repository: groupRepository,
                         identity: identity,
                         reporter: groups.errorReporter,
                         logger: logger,
                         onChange: onChange)
    }

    func makeInviteViewModel(for group: SportGroup) -> InviteViewModel {
        InviteViewModel(group: group,
                        repository: inviteRepository,
                        reporter: groups.errorReporter,
                        recorder: interactionRecorder,
                        pasteboard: groups.pasteboard,
                        logger: logger)
    }

    func makeJoinWithCodeViewModel(onJoined: @escaping @MainActor (SportGroup) -> Void) -> JoinWithCodeViewModel {
        JoinWithCodeViewModel { [self] code in makeInvitePreviewViewModel(code: code, onJoined: onJoined) }
    }

    func makeInvitePreviewViewModel(code: InviteCode,
                                    onJoined: @escaping @MainActor (SportGroup) -> Void) -> InvitePreviewViewModel {
        InvitePreviewViewModel(code: code,
                               invites: inviteRepository,
                               groups: groupRepository,
                               identity: identity,
                               store: myGroups,
                               navigation: navigation,
                               reporter: groups.errorReporter,
                               logger: logger,
                               onJoined: onJoined)
    }
}
