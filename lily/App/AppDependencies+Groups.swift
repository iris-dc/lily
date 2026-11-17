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
    /// Invites into an event, behind the same seam; the mock reads the event mock's participants.
    let eventInvites: any InviteRepository
    let realtimeTransport: any RealtimeTransport
    let makeRealtimeEndpointProvider: @MainActor (MeStore) -> any RealtimeEndpointProvider
    /// Moves attachment files into the bucket (or the mock store) through presigned targets.
    let attachmentUploader: any AttachmentUploader
    /// Turns picked pictures, videos and files into drafts; the mock one also stands in for the pickers under
    /// `-mock-attachment-picker`.
    let mediaPreparer: any MediaPreparer
    /// Downloads attachment bytes from their presigned links; the mock one resolves the mock store's `mock://` URLs.
    let attachmentSession: URLSession

    /// The remote set over the app's one API client. The transport is the AppSync Events client over its own socket,
    /// reading the token afresh from the same provider the API client sends; the endpoint provider answers what
    /// `GET /api/me` named (or the debug `-realtime-endpoint` override).
    static func remote(client: any APIClient,
                       realtimeEndpoint: URL?,
                       identity: any IdentityProvider,
                       tokenProvider: (any AuthTokenProvider)?,
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
                          eventInvites: RemoteEventInviteRepository(client: client),
                          realtimeTransport: AppSyncRealtimeTransport(socket: URLSessionEventsSocket(),
                                                                      tokenProvider: tokenProvider,
                                                                      logger: logger),
                          makeRealtimeEndpointProvider: { me in
                              RemoteRealtimeEndpointProvider(override: realtimeEndpoint, me: me)
                          },
                          attachmentUploader: URLSessionAttachmentUploader(logger: logger),
                          mediaPreparer: DeviceMediaPreparer(logger: logger),
                          attachmentSession: URLSession(configuration: .default))
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
        [myGroups, me, inbox, blocks, chatHistory, catchUp, outbox, unreadCenter, attachments.loader, attachments.cache, realtime]
    }
}

extension AppDependencies {
    var groupRepository: any GroupRepository { groups.repositories.groups }
    var inviteRepository: any InviteRepository { groups.repositories.invites }
    var tournamentInviteRepository: any InviteRepository { groups.repositories.tournamentInvites }
    var eventInviteRepository: any InviteRepository { groups.repositories.eventInvites }
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
                             geocoder: geocoder,
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

    /// The same sheet from an event's detail, over the event's invite routes.
    func makeEventInvitePeopleViewModel(for eventID: String) -> InvitePeopleViewModel {
        InvitePeopleViewModel(target: .event(id: eventID),
                              repository: eventInviteRepository,
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
