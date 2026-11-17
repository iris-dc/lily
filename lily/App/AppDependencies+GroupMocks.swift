import Foundation

/// The mock side of `GroupRepositories`, split from `AppDependencies+Groups.swift` under the file-length limit.
extension GroupRepositories {
    /// The mocks that share one group and one tournament instance; split out of `mock` for its body-length limit.
    private struct DataMocks {
        let groups: MockGroupRepository
        let tournaments: MockTournamentRepository
        let inbox: MockInboxRepository
        let tournamentInvites: MockTournamentInviteRepository
        let eventInvites: MockEventInviteRepository
    }

    private static func makeDataMocks(identity: any IdentityProvider,
                                      logger: any Logging,
                                      events: MockEventRepository,
                                      deletedFixtures: Bool) -> DataMocks {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        // The event mock was built before the group mock exists; close the loop so its writes reach the rooms.
        events.rooms = groups
        let tournaments = MockTournamentRepository(groups: groups,
                                                   identity: identity,
                                                   logger: logger,
                                                   deletedFixtures: deletedFixtures)
        let inbox = MockInboxRepository(groups: groups,
                                        tournaments: tournaments,
                                        events: events,
                                        identity: identity,
                                        logger: logger,
                                        deletedUser: deletedFixtures)
        let invites = MockTournamentInviteRepository(groups: groups, tournaments: tournaments, identity: identity, logger: logger)
        let eventInvites = MockEventInviteRepository(groups: groups, events: events, identity: identity, logger: logger)
        return DataMocks(groups: groups,
                         tournaments: tournaments,
                         inbox: inbox,
                         tournamentInvites: invites,
                         eventInvites: eventInvites)
    }

    /// The invite mock reads the group mock's rosters, the inbox mock admits into its groups, enters the tournament
    /// mock's tournaments and joins the event mock's games, the event mock mirrors every create and participation into
    /// the group mock's rooms, the chat mock reads the rosters and the user mock builds profiles from them (and the shared
    /// history from the event and tournament mocks, the caller's own bio from the profile mock), so they share one
    /// group instance (and the two tournament mocks one tournament instance); the chat mock echoes over the one
    /// in-memory bus the controller subscribes to, and the chat mock, the uploader and the loader's session share one
    /// attachment store. `mockPicker` swaps the system pickers for the bundled photo, clip and document
    /// (`-mock-attachment-picker`); `deletedFixtures` makes the chat, tournament, inbox (and, built by the
    /// caller, event) mocks serve the deleted-flagged fixtures (`-mock-deleted-user`).
    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     events: MockEventRepository,
                     profiles: MockProfileRepository,
                     autoReplies: Bool = false,
                     mockPicker: Bool = false,
                     deletedFixtures: Bool = false) -> GroupRepositories {
        let mocks = makeDataMocks(identity: identity, logger: logger, events: events, deletedFixtures: deletedFixtures)
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
                                 eventInvites: mocks.eventInvites,
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
