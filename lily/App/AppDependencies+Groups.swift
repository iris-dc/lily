import Foundation

/// The repositories and the realtime transport of the groups feature, built together in `Repositories` so a mock run
/// stays in memory throughout. The endpoint provider is built once `MeStore` exists, because the real one reads it.
struct GroupRepositories {
    let groups: any GroupRepository
    let invites: any InviteRepository
    let inbox: any InboxRepository
    let me: any MeRepository
    let moderation: any ModerationRepository
    let chat: any ChatRepository
    let users: any UserRepository
    /// Tournaments and their entries; the mock shares the group mock, whose rooms a tournament's players enter.
    let tournaments: any TournamentRepository
    /// Invites into a tournament, behind the same seam as the group invites; the mock reads the tournament mock.
    let tournamentInvites: any InviteRepository
    let realtimeTransport: any RealtimeTransport
    let makeRealtimeEndpointProvider: @MainActor (MeStore) -> any RealtimeEndpointProvider
    /// Moves attachment files into the bucket (or the mock store) through presigned targets.
    let attachmentUploader: any AttachmentUploader
    /// Turns picked pictures, videos and files into drafts; the mock one also stands in for the pickers under
    /// `-mock-attachment-picker`.
    let mediaPreparer: any MediaPreparer
    /// Downloads attachment bytes from their presigned links; the mock one resolves the mock store's `mock://` URLs.
    let attachmentSession: URLSession

    /// The remote set over the app's one API client. The transport is `NoRealtimeTransport` until the AppSync client
    /// is added; the endpoint provider already discovers the endpoint, so that swap is one line here.
    static func remote(client: any APIClient,
                       realtimeEndpoint: URL?,
                       identity: any IdentityProvider,
                       logger: any Logging) -> GroupRepositories {
        GroupRepositories(groups: RemoteGroupRepository(client: client, identity: identity),
                          invites: RemoteInviteRepository(client: client),
                          inbox: RemoteInboxRepository(client: client),
                          me: RemoteMeRepository(client: client),
                          moderation: RemoteModerationRepository(client: client),
                          chat: RemoteChatRepository(client: client),
                          users: RemoteUserRepository(client: client),
                          tournaments: RemoteTournamentRepository(client: client),
                          tournamentInvites: RemoteTournamentInviteRepository(client: client),
                          realtimeTransport: NoRealtimeTransport(),
                          makeRealtimeEndpointProvider: { me in
                              RemoteRealtimeEndpointProvider(override: realtimeEndpoint, me: me)
                          },
                          attachmentUploader: URLSessionAttachmentUploader(logger: logger),
                          mediaPreparer: DeviceMediaPreparer(logger: logger),
                          attachmentSession: URLSession(configuration: .default))
    }

    /// The invite mock reads the group mock's rosters, the inbox mock admits into its groups and enters the tournament
    /// mock's tournaments, the chat mock reads the rosters and the user mock builds profiles from them, so they share
    /// one group instance (and the two tournament mocks one tournament instance); the chat mock echoes over the one
    /// in-memory bus the controller subscribes to, and the chat mock, the uploader and the loader's session share one
    /// attachment store. `mockPicker` swaps the system pickers for the bundled photo, clip and document
    /// (`-mock-attachment-picker`).
    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     autoReplies: Bool,
                     mockPicker: Bool = false) -> GroupRepositories {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        let tournaments = MockTournamentRepository(groups: groups, identity: identity, logger: logger)
        let transport = MockRealtimeTransport(logger: logger)
        let attachments = MockAttachmentStore()
        MockAttachmentURLProtocol.serve(attachments)
        return GroupRepositories(groups: groups,
                                 invites: MockInviteRepository(groups: groups, identity: identity, logger: logger),
                                 inbox: MockInboxRepository(groups: groups,
                                                            tournaments: tournaments,
                                                            identity: identity,
                                                            logger: logger),
                                 me: MockMeRepository(identity: identity, logger: logger),
                                 moderation: MockModerationRepository(logger: logger),
                                 chat: MockChatRepository(groups: groups,
                                                          transport: transport,
                                                          identity: identity,
                                                          logger: logger,
                                                          attachments: attachments,
                                                          autoReplies: autoReplies),
                                 users: MockUserRepository(groups: groups, identity: identity, logger: logger),
                                 tournaments: tournaments,
                                 tournamentInvites: MockTournamentInviteRepository(groups: groups,
                                                                                   tournaments: tournaments,
                                                                                   identity: identity,
                                                                                   logger: logger),
                                 realtimeTransport: transport,
                                 makeRealtimeEndpointProvider: { _ in
                                     FixedRealtimeEndpointProvider(url: AppConfig.Realtime.mockEndpoint)
                                 },
                                 attachmentUploader: MockAttachmentUploader(store: attachments),
                                 mediaPreparer: mockPicker
                                     ? MockMediaPreparer(logger: logger)
                                     : DeviceMediaPreparer(logger: logger),
                                 attachmentSession: MockAttachmentURLProtocol.makeSession())
    }
}

/// The collaborators of groups, chat, the inbox and moderation, held as one value so `AppDependencies` gains a single
/// stored property however many the feature needs. The repositories are read through the set they came in.
struct GroupDependencies {
    let repositories: GroupRepositories
    /// The one source of the caller's groups for every screen and store that needs them.
    let myGroups: MyGroupsStore
    let me: MeStore
    /// The caller's invites and reminders; the Chats row, the tab badge and the inbox screen read it.
    let inbox: InboxStore
    /// The rooms held in memory; the open chat and the realtime controller share it.
    let chatHistory: InMemoryChatHistoryCache
    let unreadCenter: UnreadCenter
    let catchUp: ChatCatchUp
    let realtime: RealtimeSessionController
    /// The cache, loader, uploader and preparer of chat attachments (`AppDependencies+Chat.swift`).
    let attachments: AttachmentDependencies
    /// Every groups and chat screen reports failures through it: the popup, plus `MeStore.noteTermsRequired()` on `TERMS_REQUIRED`.
    let errorReporter: GroupErrorReporter
    let pasteboard: any Pasteboard
    let navigation = AppNavigation()
    /// Counts group changes made anywhere, as `AppDependencies.eventChanges` does for events.
    let groupChanges = ChangeTracker()
    /// Counts tournament changes made anywhere, the realtime controller's included; `TournamentDependencies` shares it.
    let tournamentChanges = ChangeTracker()

    var groupRepository: any GroupRepository { repositories.groups }
    var inviteRepository: any InviteRepository { repositories.invites }
    var tournamentInviteRepository: any InviteRepository { repositories.tournamentInvites }
    var inboxRepository: any InboxRepository { repositories.inbox }
    var meRepository: any MeRepository { repositories.me }
    var moderationRepository: any ModerationRepository { repositories.moderation }
    var chatRepository: any ChatRepository { repositories.chat }
    var userRepository: any UserRepository { repositories.users }

    init(repositories: GroupRepositories,
         identity: any IdentityProvider,
         tokenProvider: (any AuthTokenProvider)?,
         errorCenter: ErrorCenter,
         logger: any Logging,
         pasteboard: any Pasteboard = SystemPasteboard()) {
        self.repositories = repositories
        let myGroups = MyGroupsStore(repository: repositories.groups,
                                     identity: identity,
                                     changes: groupChanges,
                                     errorCenter: errorCenter,
                                     logger: logger)
        self.myGroups = myGroups
        let me = MeStore(repository: repositories.me, identity: identity, errorCenter: errorCenter, logger: logger)
        self.me = me
        let inbox = InboxStore(repository: repositories.inbox, identity: identity, errorCenter: errorCenter, logger: logger)
        self.inbox = inbox
        errorReporter = GroupErrorReporter(errorCenter: errorCenter) { me.noteTermsRequired() }
        let chatHistory = InMemoryChatHistoryCache(logger: logger)
        self.chatHistory = chatHistory
        let unreadCenter = UnreadCenter()
        self.unreadCenter = unreadCenter
        let catchUp = ChatCatchUp(repository: repositories.chat, cache: chatHistory, logger: logger)
        self.catchUp = catchUp
        attachments = AttachmentDependencies(repositories: repositories, logger: logger)
        realtime = RealtimeSessionController(transport: repositories.realtimeTransport,
                                             endpointProvider: repositories.makeRealtimeEndpointProvider(me),
                                             tokenProvider: tokenProvider,
                                             identity: identity,
                                             store: myGroups,
                                             cache: chatHistory,
                                             catchUp: catchUp,
                                             unread: unreadCenter,
                                             inbox: inbox,
                                             groupChanges: groupChanges,
                                             tournamentChanges: tournamentChanges,
                                             groupRepository: repositories.groups,
                                             errorCenter: errorCenter,
                                             logger: logger)
        self.pasteboard = pasteboard
    }

    /// Everything here that holds state for the signed-in user; `SessionController` tells them when the session ends.
    var sessionObservers: [any SessionObserver] {
        [myGroups, me, inbox, chatHistory, unreadCenter, attachments.cache, realtime, navigation]
    }
}

extension AppDependencies {
    var groupRepository: any GroupRepository { groups.groupRepository }
    var inviteRepository: any InviteRepository { groups.inviteRepository }
    var tournamentInviteRepository: any InviteRepository { groups.tournamentInviteRepository }
    var meRepository: any MeRepository { groups.meRepository }
    var moderationRepository: any ModerationRepository { groups.moderationRepository }
    var myGroups: MyGroupsStore { groups.myGroups }
    var me: MeStore { groups.me }
    var navigation: AppNavigation { groups.navigation }
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

    /// The invite-people sheet of a group's detail.
    func makeInvitePeopleViewModel(for group: SportGroup) -> InvitePeopleViewModel {
        InvitePeopleViewModel(target: .group(id: group.id),
                              repository: inviteRepository,
                              reporter: groups.errorReporter,
                              logger: logger)
    }

    /// The same sheet from a tournament's detail, over the tournament's invite routes.
    func makeTournamentInvitePeopleViewModel(for tournamentID: String) -> InvitePeopleViewModel {
        InvitePeopleViewModel(target: .tournament(id: tournamentID),
                              repository: tournamentInviteRepository,
                              reporter: groups.errorReporter,
                              logger: logger)
    }

    /// The report sheet for one target; `title` names what is reported.
    func makeReportViewModel(for target: ReportTarget, title: String) -> ReportViewModel {
        ReportViewModel(target: target,
                        title: title,
                        repository: moderationRepository,
                        reporter: groups.errorReporter,
                        logger: logger)
    }
}
