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
    /// mock's tournaments, the chat mock reads the rosters and the user mock builds profiles from them (and the shared
    /// history from the event and tournament mocks, the caller's own bio from the profile mock), so they share one
    /// group instance (and the two tournament mocks one tournament instance); the chat mock echoes over the one
    /// in-memory bus the controller subscribes to, and the chat mock, the uploader and the loader's session share one
    /// attachment store. `mockPicker` swaps the system pickers for the bundled photo, clip and document
    /// (`-mock-attachment-picker`); `deletedFixtures` makes the chat, tournament, inbox (and, built by the
    /// caller, event) mocks serve the deleted-flagged fixtures (`-mock-deleted-user`).
    /// The mocks that share one group and one tournament instance; split out of `mock` for its body-length limit.
    private struct DataMocks {
        let groups: MockGroupRepository
        let tournaments: MockTournamentRepository
        let inbox: MockInboxRepository
        let tournamentInvites: MockTournamentInviteRepository
    }

    private static func makeDataMocks(identity: any IdentityProvider,
                                      logger: any Logging,
                                      deletedFixtures: Bool) -> DataMocks {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        let tournaments = MockTournamentRepository(groups: groups,
                                                   identity: identity,
                                                   logger: logger,
                                                   deletedFixtures: deletedFixtures)
        let inbox = MockInboxRepository(groups: groups,
                                        tournaments: tournaments,
                                        identity: identity,
                                        logger: logger,
                                        deletedUser: deletedFixtures)
        let invites = MockTournamentInviteRepository(groups: groups, tournaments: tournaments, identity: identity, logger: logger)
        return DataMocks(groups: groups, tournaments: tournaments, inbox: inbox, tournamentInvites: invites)
    }

    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     events: MockEventRepository,
                     profiles: MockProfileRepository,
                     autoReplies: Bool = false,
                     mockPicker: Bool = false,
                     deletedFixtures: Bool = false) -> GroupRepositories {
        let mocks = makeDataMocks(identity: identity, logger: logger, deletedFixtures: deletedFixtures)
        let transport = MockRealtimeTransport(logger: logger)
        let attachments = MockAttachmentStore()
        MockAttachmentURLProtocol.serve(attachments)
        return GroupRepositories(groups: mocks.groups,
                                 invites: MockInviteRepository(groups: mocks.groups, identity: identity, logger: logger),
                                 inbox: mocks.inbox,
                                 me: MockMeRepository(identity: identity, logger: logger),
                                 moderation: MockModerationRepository(logger: logger),
                                 chat: MockChatRepository(groups: mocks.groups,
                                                          transport: transport,
                                                          identity: identity,
                                                          logger: logger,
                                                          attachments: attachments,
                                                          autoReplies: autoReplies,
                                                          deletedSender: deletedFixtures),
                                 users: MockUserRepository(groups: mocks.groups,
                                                           events: events,
                                                           tournaments: mocks.tournaments,
                                                           profiles: profiles,
                                                           identity: identity,
                                                           logger: logger),
                                 tournaments: mocks.tournaments,
                                 tournamentInvites: mocks.tournamentInvites,
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
    /// The caller's block list; every room's rows read it and every block replaces it.
    let blocks: BlockListStore
    /// The rooms held in memory; the open chat and the realtime controller share it.
    let chatHistory: InMemoryChatHistoryCache
    /// The unsent and failed messages of every room; every open chat reads and writes its own there.
    let outbox = ChatOutbox()
    let unreadCenter: UnreadCenter
    let catchUp: ChatCatchUp
    let realtime: RealtimeSessionController
    /// The cache, loader, uploader and preparer of chat attachments (`AppDependencies+Chat.swift`).
    let attachments: AttachmentDependencies
    let pasteboard: any Pasteboard = SystemPasteboard()
    /// Counts group changes made anywhere, as `AppDependencies.eventChanges` does for events.
    let groupChanges = ChangeTracker()
    /// Counts tournament changes made anywhere, the realtime controller's included; every tournament list reloads on it.
    let tournamentChanges = ChangeTracker()

    /// `snapshots` is where Mine keeps its last answer for the first frame of the next launch; the identity must
    /// already answer for the cached session, since the store reads the caller to pick the snapshot it starts from.
    init(repositories: GroupRepositories,
         identity: any IdentityProvider,
         tokenProvider: (any AuthTokenProvider)?,
         errorCenter: ErrorCenter,
         logger: any Logging,
         snapshots: any ListSnapshotStore = NoOpListSnapshotStore()) {
        self.repositories = repositories
        let myGroups = MyGroupsStore(repository: repositories.groups,
                                     identity: identity,
                                     changes: groupChanges,
                                     errorCenter: errorCenter,
                                     logger: logger,
                                     snapshots: snapshots)
        self.myGroups = myGroups
        let me = MeStore(repository: repositories.me, identity: identity, logger: logger)
        self.me = me
        let inbox = InboxStore(repository: repositories.inbox, identity: identity, errorCenter: errorCenter, logger: logger)
        self.inbox = inbox
        blocks = BlockListStore(repository: repositories.moderation, identity: identity, logger: logger)
        let chatHistory = InMemoryChatHistoryCache(activity: myGroups, logger: logger)
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
    }

    /// Everything here that holds state for the signed-in user; `SessionController` tells them when the session ends,
    /// awaiting `sessionWillEnd` in this order: the loader ends its downloads before the cache sweeps.
    var sessionObservers: [any SessionObserver] {
        [myGroups, me, inbox, blocks, chatHistory, outbox, unreadCenter, attachments.loader, attachments.cache, realtime]
    }
}

extension AppDependencies {
    var groupRepository: any GroupRepository { groups.repositories.groups }
    var inviteRepository: any InviteRepository { groups.repositories.invites }
    var tournamentInviteRepository: any InviteRepository { groups.repositories.tournamentInvites }
    var meRepository: any MeRepository { groups.repositories.me }
    var moderationRepository: any ModerationRepository { groups.repositories.moderation }
    var myGroups: MyGroupsStore { groups.myGroups }
    var me: MeStore { groups.me }
    var blocks: BlockListStore { groups.blocks }
    var groupChanges: ChangeTracker { groups.groupChanges }

    /// Discover's own screen keeps no snapshot (the default); the carousel on Explore passes the app's store.
    func makeDiscoverGroupsViewModel(snapshots: any ListSnapshotStore = NoOpListSnapshotStore()) -> DiscoverGroupsViewModel {
        DiscoverGroupsViewModel(changes: groupChanges,
                                repository: groupRepository,
                                identity: identity,
                                locationService: locationService,
                                errorCenter: errorCenter,
                                recorder: interactionRecorder,
                                logger: logger,
                                snapshots: snapshots)
    }

    func makeGroupDetailViewModel(for group: SportGroup, context: GroupDetailContext) -> GroupDetailViewModel {
        GroupDetailViewModel(group: group,
                             context: context,
                             repository: groupRepository,
                             identity: identity,
                             store: myGroups,
                             errorCenter: errorCenter,
                             recorder: interactionRecorder,
                             logger: logger)
    }

    func makeGroupLoaderViewModel(ref: EventGroupRef) -> GroupLoaderViewModel {
        GroupLoaderViewModel(ref: ref, repository: groupRepository, errorCenter: errorCenter, logger: logger)
    }

    func makeCreateGroupViewModel(onCreated: @escaping @MainActor (SportGroup) -> Void) -> CreateGroupViewModel {
        CreateGroupViewModel(repository: groupRepository,
                             identity: identity,
                             store: myGroups,
                             locationService: locationService,
                             errorCenter: errorCenter,
                             logger: logger,
                             onCreated: onCreated)
    }

    func makeEditGroupViewModel(for group: SportGroup,
                                onChange: @escaping @MainActor (SportGroup) -> Void) -> EditGroupViewModel {
        EditGroupViewModel(group: group,
                           repository: groupRepository,
                           errorCenter: errorCenter,
                           logger: logger,
                           onChange: onChange)
    }

    func makeMembersViewModel(for group: SportGroup,
                              onChange: @escaping @MainActor (SportGroup) -> Void) -> MembersViewModel {
        MembersViewModel(group: group,
                         repository: groupRepository,
                         identity: identity,
                         errorCenter: errorCenter,
                         logger: logger,
                         onChange: onChange)
    }

    /// The invite-people sheet of a group's detail.
    func makeInvitePeopleViewModel(for group: SportGroup) -> InvitePeopleViewModel {
        InvitePeopleViewModel(target: .group(id: group.id),
                              repository: inviteRepository,
                              errorCenter: errorCenter,
                              logger: logger)
    }

    /// The same sheet from a tournament's detail, over the tournament's invite routes.
    func makeTournamentInvitePeopleViewModel(for tournamentID: String) -> InvitePeopleViewModel {
        InvitePeopleViewModel(target: .tournament(id: tournamentID),
                              repository: tournamentInviteRepository,
                              errorCenter: errorCenter,
                              logger: logger)
    }

    /// The report sheet for one target; `title` names what is reported.
    func makeReportViewModel(for target: ReportTarget, title: String) -> ReportViewModel {
        ReportViewModel(target: target,
                        title: title,
                        repository: moderationRepository,
                        errorCenter: errorCenter,
                        logger: logger)
    }
}
