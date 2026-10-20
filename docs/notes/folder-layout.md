# Folder layout, in detail

> The full folder tree with a line per file group. Moved out of `README.md` and `CLAUDE.md` on 2026-10-17 and kept as written. It is the README's tree as it stood then, with a line per file group. Read this file before touching the area; the rules that apply everywhere are in `AGENTS.md`.

```
lily/
  App/           LilyApp (entry), LilyAppDelegate (the UIKit callbacks SwiftUI lacks: the APNs token and notification taps, posted
                 to PushEventRelay), AppRootView (state switch, wiring only: one task per scene phase and user
                 drives ShellSync), AppDependencies (composition root) + AppDependencies+Groups (GroupRepositories, the set the
                 remote and mock wirings build; GroupDependencies: the group, invite, inbox, account, moderation and chat
                 repositories, MyGroupsStore, MeStore, InboxStore, the chat cache, UnreadCenter, the realtime controller,
                 GroupErrorReporter, the pasteboard, the group and tournament change trackers, ChatOutbox, BlockListStore, the session observers to register; the
                 factories of every groups view model, the invite sheet's included) + AppDependencies+Chat, +Inbox and +People (the
                 chat, inbox and profile factories) + AppDependencies+Events (the event view-model factories) + AppDependencies+Push
                 (PushDependencies: the registrar and device repository the data layer chose, EventOpener, TournamentOpener,
                 PushCoordinator)
                 + AppDependencies+Localization (the language store built from the stored choice and the launch arguments)
                 + AppDependencies+Tournaments (the tournament repository and change tracker over the group dependencies; the
                 tournament view-model factories) + AppDependencies+Moderation (the terms sheet's view model) + AppDependencies+Session
                 (the session store settled from the launch arguments; -reset-session decided and logged once as startsFresh and handed to
                 the session, language, currency and filter stores) + AppDependencies+Shell (makeShellSync) + AppDependencies+Currency
                 + AppDependencies+Feedback + AppDependencies+LaunchArguments (the value-taking arguments' URL helpers)
  Localizable.xcstrings, InfoPlist.xcstrings   the string catalogs: every line of copy in seven languages, and the usage descriptions
  Config/        AppConfig (non-visual constants), AppBranding (product copy, every line read through localized(_:)), DesignTokens (spacing, radii, durations, SF Symbol names),
                 AccessibilityIdentifiers (the identifiers UI tests query); the groups, chat, realtime, moderation, people, shell
                 and language constants, copy, tokens and identifiers live in +Groups / +Chat / +Realtime / +Moderation / +People /
                 +Shell / +Localization / +Settings / +FeatureFlags / +Tournaments / +TournamentResults / +TournamentInvites /
                 +ChatTournaments extension files so SwiftLint's type_body_length never trips on the four main types
  Core/
    Auth/        Models (AuthUser, AuthSession + StoredSession (guest, signed in, or signing out: a sign-out the pool has not confirmed yet),
                 EmailAuthResult, ConfirmOutcome, SignUpOutcome, SessionState, AuthProvider), Interfaces (AuthService, SessionStore,
                 IdentityProvider, CognitoClient, AuthTokenProvider, SessionObserver),
                 Implementations (CognitoAuthService over AmplifyCognitoClient, the only file importing Amplify, configured
                 from AmplifyConfigurationBuilder; JWTClaims; Mock*, UserDefaults*, SessionIdentityProvider), SessionController
    Changes/     ChangeTracker (observable change counter; one per kind of data, so lists that missed a change reload),
                 ContentFreshness (the shared staleness rules: TTL, change version, caller, coarse position, retry cooldown; .standard
                 over AppConfig.Lists), StoreLoader (the app-lifetime stores' load skeleton: SingleFlight keyed by user +
                 ContentFreshness, a version that moved mid-request loaded once more), ListState (loading / empty / failed / content,
                 what a list segment draws)
    Concurrency/ Sleep (the injectable pause timers and debounces wait on; systemSleep is Task.sleep), SingleFlight (one run of a
                 load at a time in a task of its own; callers made while it runs join it; the per-user stores' load), DetachedWork (work off the main
                 actor that dies with its caller: the media preparers' one hop), SlotGate (at most N at once, the rest in order, a
                 cancelled waiter handing its slot on: the upload cap), Deadline (two unstructured tasks, the first outcome wins, the loser
                 cancelled but not awaited: the sign-out's caps on the device removal and the statistics flush)
    Foundation/  String+Trimming (trimmed and nonBlankTrimmed, how every typed field is read)
    Realtime/    Interfaces (RealtimeTransport, RealtimeEndpointProvider), Models (RealtimeChannel, RealtimeEnvelope, RealtimeConnectionState,
                 RealtimeTransportError, Backoff + RenewalDelay (the pure reconnect and renewal waits)), Implementations (MockRealtimeTransport: the in-memory bus of a mock run; NoRealtimeTransport;
                 RemoteRealtimeEndpointProvider, FixedRealtimeEndpointProvider), RealtimeSessionController (+Connection, +Routing):
                 the one connection, its rooms, its renewal and the resume protocol
    Navigation/  AppNavigation (selected tab + the Home and Chats stack paths, for pushes made from outside a tab: open(group:) on
                 Home, open(chat:) and openInChat(_:) on Chats; startTab(for:); a SessionObserver, reset on sign-out)
    System/      Pasteboard interface + SystemPasteboard (UIPasteboard), so copying is testable; FileManager+RemoveIfPresent (remove when
                 there, nothing when not, throw when refused); Calendar+NextFullHour (the forms' proposed start, a date on the hour kept)
    Push/        Models (PushEnvironment, DeviceRegistration + payload and removal, LastDeviceRegistration, PushAuthorization,
                 PushPayload + PushTap (what a tapped notification opens: a game, or a tournament's match)), Interfaces (PushRegistrar, DeviceRepository, PushOptIn), Implementations (SystemPushRegistrar over
                 UNUserNotificationCenter and the relay, MockPushRegistrar, RemoteDeviceRepository, MockDeviceRepository,
                 PushEventRelay, NoPushOptIn), PushCoordinator (registration sync, the permission ask, the tapped reminder)
    Errors/      AppError, ErrorMessageMapper (single copy source; the groups, chat, moderation, people and tournament copy in
                 ErrorMessageMapper+Groups / +Chat / +Events / +People / +Tournaments), ErrorCenter (drives the popup)
    Localization/ AppLanguage (the seven languages, the system's pick), LanguagePreference (system or fixed, a StoredChoice), AppLocale
                 (the process-wide language for lookups and formats; the region read per call), localized(_:) (the one lookup every
                 line of copy goes through), LanguageStore (the user's choice, persisted and published)
    Currency/    CurrencyPreference (system or a fixed ISO code, a StoredChoice; an unoffered stored code reads as system), CurrencyStore
                 (the currency prices are typed in and the price cap is judged in: the Profile choice, else the region's, else EUR)
    Preferences/ Interfaces (StoredChoice: a Profile choice kept in UserDefaults as one string, "system" or its code; ChoiceStore),
                 Implementations (UserDefaultsChoiceStore, the one store behind the language and the currency choices)
    Logging/     Logging facade + OSLogLogger
    Networking/  APIClient interface, APIRequest/APIError models, WireNamedKind (a kind sent as one string, with an unknown case
                 every kind keeps: MessageKind, GroupKind, InboxItemKind, EventType, SkillLevel, AttachmentKind), EmptyBody (NoContent and OptionalBody, the answers of routes that may say nothing),
                 Coordinate+QueryItems (the coarse lat/lon every Explore list sends), Page (the {items, nextCursor} envelope every
                 paged list decodes), URLSessionAPIClient + JSON conventions (queries percent-encoded, refusals logged at warning and
                 faults at error), APIFailureMapping (backend codes to AppError, one exhaustive switch), LostRace (the one TRY_AGAIN
                 repeat every write shares, logging the retry line itself), WriteGate (the frame around one plain write: the repeat,
                 quiet cancellation, the failure logged and reported, a Bool back), CreateFlow (the create forms' send, unknown-outcome
                 lookup and ownership check)
    Statistics/  Models (Interaction, InteractionKind, FilterSummary, InteractionBatch, InteractionReceipt), the
                 InteractionRecorder interface, RemoteInteractionRecorder (batching) and NoOpInteractionRecorder (mock runs)
    Location/    Coordinate model (+ CoreLocation bridge), LocationFix, interfaces (LocationService, LocationUpdateSource),
                 implementations (CoreLocation update source and service, caching decorator, mock)
    Validation/  CredentialsValidator (mirroring the backend's @Email: no inner whitespace, one @, a 64-unit local part), String+WireLength
                 (UTF-16 length, as the backend counts text), Collection+FirstOf (the one first-present-issue rule of the forms)
    UI/          Theme (fonts, aurora role-to-color mapping), Effects (aurora geometry, roles, film grain: pure, testable math),
                 Components (aurora background, content-screen scaffold, glass cards, button modifiers, provider buttons, error popup,
                 ScreenTitle + ScreenSubtitle, AvatarCircle, String+Initials (the one initials rule, beside AvatarCircle),
                 UnreadDot, ConversationRow (avatar + title + caption + dot, shared by the Chats rows and the
                 inbox row) and AvatarRowDivider (the divider that starts at their text column), EventTypeChips (the one
                 type-chip flow of the filter, the event form and the group form), EntriesBar (the one "how full" bar; CapacityBar
                 draws an event through it), TypeFilterButton + TypeFilterPanel (the type dropdown of both Discover screens), GlassGlyph (a symbol as a mark in the
                 amber glass circle, drawn through AvatarCircle; the preview card's type glyph), BusyButton (a title with a spinner: join, leave,
                 Message, the tournament controls), TileCarousel + TileLink + TileContent (the group and tournament carousels, swapping to
                 TileGrid on a regular width), CardHeader (the chips-and-time header of the event and tournament cards), OwnerTitleBlock
                 (title, host or organiser line and group line of the two details), ListSegment (a list segment's loading / empty / failed
                 / content over ListState), VisibilityChip, DraftSheet (the one sheet around every create and edit form: Cancel, submit,
                 form sizing, own popup) + DraftSubmitButton + CaptionedControl (a caption over a control), FilterDropdown
                 (FilterDropdownButton + DropdownPanel, the dropdown scaffold of the event and type filters), ...), Interfaces
                 (DraftSubmitting: what DraftSheet reads from a form's view model), Layout (LayoutMode, ReadableColumn, AdaptiveCardGrid,
                 TileGrid, FormSheet, UsableWidth, FlowArrangement (the pure wrapping arithmetic behind FlowLayout), Binding+IsPresent
                 (confirmationDialog(item:)), HidesTabBarOnCompact + TabBarHiding (the stack root's animated tab-bar
                 visibility, by the hiding screen's depth))
  Features/
    Landing/     First screen: the intro pager (IntroPager, IntroSlideView, IntroPageIndicator, IntroScreenFrame, IntroScreens),
                 the slides and their content (Models/IntroSlide, IntroContent, IntroFixtures, TapPulseCurve), LandingViewModel and the two
                 buttons (Models + Views + ViewModels)
    SignIn/      Sign-in sheet with provider buttons and the email form (Views + ViewModels)
    Shell/       MainTabView (TabView(selection:) over AppTab: Home, Explore, Chats, Profile; the unread badge on Chats), HomeTab (the
                 Home stack), HomeView, HomeOverview (your groups above your games), HomeContent (guest prompt or overview, shared
                 with Chats), GuestSignInPrompt, ExploreTab (Explore with the groups and tournaments carousels), ChatTab (the Chats stack);
                 Models (HomeOverviewState + HomeListSnapshot + HomeSectionState: Home's spinner / empty / sections rule while its three
                 loads run; CreateIntent, the keyboard shortcuts' request), Services (ShellSync: the restore that lands on the start tab
                 and opens a pending notification tap, and the per-user run: account, realtime, Mine, inbox, block list, push, in order)
    Events/      Models (SportEvent with optional Price and SkillLevel, EventType and SkillLevel (both keeping a wire value this build does
                 not know as unknown), EventFilter + PersistedEventFilter, DateWindow, Participation, MapFraming + PickerSettlePolicy (the
                 map's opening region; when a settle is the user's choice),
                 EventsPresentation, EventDraft (with its editing init and Rules; the price field's text lives on it) and the
                 Create/UpdateEventPayloads, EventScope with its group case (and the scopes' wire names), EventParticipant, EventLocation
                 (the one distance rule of events, groups and tournaments), PlaceDraft (the shared place validation of the event and
                 tournament drafts), EventListScreenState (Explore's loading / failed / empty / filtered-out / list ladder),
                 CreateIntentPolicy + ExploreSheet (which sheet a create request or a shortcut opens; sign-in for a guest); SportEvent and
                 EventDraft carry an optional EventGroupRef), Interfaces (EventRepository, EventFilterStore, EventDraftEditing),
                 Implementations (remote and mock repositories, MockEventFixtures with the mock's participant names in MockEventFixtures+Participants),
                 ViewModels (list with its filter extension, detail with who is in, create, edit), Views (cards, EventCardList (the
                 bare card list), list screen, map, detail with the host's Edit button, ParticipantRow, preview card, filter button
                 and panel (over SkillLevelPicker, the one level picker), create button, the Create/Edit sheets (thin wrappers over
                 EventDraftSheet, itself a thin wrapper over the shared DraftSheet around the generic EventDraftForm), PlaceFields (the
                 place name plus the PlacePickerRow of the event, group, tournament and match-schedule forms), location picker), Services (EventOpener: fetch a game by id and push its detail, shared
                 by the inbox's reminder card and a tapped notification)
    Profile/     Guest and signed-in profile; ProfileRepository interface, remote and mock implementations, Profile models
    Feedback/    The contact form: Models (FeedbackKind, FeedbackDraft with its issues and the one payload builder,
                 FeedbackEnvironment: app version, OS version, device model, language), FeedbackRepository interface, remote
                 (POST /api/feedback) and mock implementations, FeedbackViewModel, Views (FeedbackRow on Profile, FeedbackSheet)
    Moderation/  The terms sheet: ViewModels (TermsViewModel: shown while a signed-in caller owes the terms, accept, sign out), Views
                 (TermsSheet, presented by AppRootView); the report sheet and the moderation repository stay under Groups
    Groups/      Groups, invites, the account and moderation: Models (SportGroup with GroupKind and Counterpart (a direct
                 conversation is a group of kind direct), GroupMember,
                 GroupMembership, GroupVisibility, MemberRole, GroupAccess, GroupDraft and the create/update payloads, GroupScope (with
                 the Discover query's searchPrefix), GroupDetailSection, GroupConfirmation (the detail's leave / delete / remove / ban
                 dialogs), InviteCandidate (with its source and caption), SentInvite (with the
                 send payload; into a group or a tournament), InviteTarget (what the invite sheet invites into), EventGroupRef, MembershipChange, RoomSubscription, GroupDetailContext,
                 Account, Report models), Interfaces (GroupRepository, InviteRepository, MeRepository, ModerationRepository, GroupDraftEditing),
                 Implementations (Remote* over APIClient, Mock* with the six fixture groups; MockGroupRepository+Direct holds the
                 mock's direct conversations and who a user id names, +Tournaments the rooms the tournament mock registers,
                 admits into and leaves, +Discover the mock's Discover filter and its three orders over GroupScope.searchPrefix;
                 MockInviteCandidatePool + MockInviteLedger, the candidate pool (every non-direct membership, tournament rooms included)
                 and the one send both invite mocks call), State (MyGroupsStore, MeStore, BlockListStore: the one block list, loaded by
                 the shell sync), Services (GroupErrorReporter), ViewModels (DiscoverGroups (the Discover search behind the carousel and
                 the Discover screen; Home reads MyGroupsStore.communities directly), GroupDetail, GroupLoader,
                 CreateGroup, EditGroup, Members, InvitePeople (over an InviteTarget), Report), Views (GroupCarousel, GroupTile, DiscoverGroupsView, DiscoverGroupList, GroupRowList,
                 GroupRow (with GroupRowContent, the row from its fields), GroupCard, GroupBadge,
                 GroupDetailView with GroupHeader, HostedInLine (the "Hosted in" line of the event and tournament title blocks),
                 GroupActionRow, GroupDetailMenu, GroupEventsSegment, MembersList, MemberRow, GroupLoaderView, the Create/Edit sheets
                 (thin wrappers over GroupDraftSheet over the shared DraftSheet around GroupDraftForm), InvitePeopleSheet over
                 InviteCandidateRow, ReportSheet (a reason, a comment, Send, thanks; a group, a tournament or a message), GroupDestinations)
    Chat/        Interfaces (ChatRepository, ChatHistoryCache, AttachmentUploader, AttachmentCache, MediaPreparer, GalleryItem), Models (ChatMessage,
                 MessageKind (text, event_created, the four tournament notes; an unknown kind decodes as `unknown(name)` and the
                 transcript hides it), MessagePage/SentMessage/ReadMarker/ClearedHistory, MessageDraft, PendingMessage, ReplyQuote (the quote a
                 reply carries), MessageArrivalCurve + TranscriptArrivals (a row's arrival from a clock, and which rows arrived), AttachmentKind (image, video, file, or an unknown kind drawn as a file), Attachment + AttachmentVariant (a stored attachment and its presigned links), AttachmentDraft
                 (an item on its way: preparing / uploading / uploaded / failed), MediaSource (what a picker handed over), PickedMovie
                 (a video from the Photos picker as a file), UploadTicket + UploadRequestPayload + AttachmentRef + AttachmentLink (the
                 upload and link routes), UploadPolicy (the backend's ticket checks, applied by the mock), UploadProgress (the ring's share of file and thumbnail bytes), GalleryLayout (pure: how a bubble
                 lays its pictures and videos out and keeps files apart as cards), FileCardInfo + VideoCaption (a card's name, size and
                 glyph; a video's length), AspectRatio (the one width-over-height rule), AttachmentSelection (the tapped tile, the
                 overflow tile opening the first hidden picture), BubbleFill (when a message's media is the bubble), MessageMenuItems (what a
                 long press offers), ChatClearPrompt (the clear / delete wording), ChatRoomState (one room: id-ordered messages,
                 tombstones, the two cursors, the cleared floor), ChatRow, ChatTimeline (pure rows: runs, day dividers, live names,
                 blocked senders), ChatDayLabel, ChatDestination, SystemRowContent (the system rows' texts, lookups and destinations over
                 SystemRowLinks + LinkedContent, which remembers what is gone) and SystemRowDestination (where a tapped one leads)), Implementations (RemoteChatRepository, MockChatRepository
                 (+ Attachments) + MockChatFixtures, InMemoryChatHistoryCache, URLSessionAttachmentUploader, DiskAttachmentCache (+ AttachmentCacheFiles, the
                 byte-moving steps off the main actor), DeviceMediaPreparer over ImagePreparer (+ ImageEncoding), VideoPreparer (+ VideoEncoding)
                 and FilePreparer (+ FileCopying), all off the main actor through DetachedWork, MockMediaPreparer (the picker stand-in), MockAttachmentStore + MockAttachmentURLProtocol,
                 MockAttachmentUploader), Services (ChatCatchUp: the REST catch-up shared by the chat and the realtime controller;
                 ChatHistoryClearer: the per-side clear; AttachmentLoader (+ Files): cache first, else one download with the link refreshed
                 and its progress reported, and the named preview file QuickLook and the player read; ReadMarkerFlusher: the read marker's
                 timing), State (UnreadCenter, ChatOutbox: every room's unsent and failed bubbles), ViewModels
                 (ChatViewModel + History + Send + Live + Events + Conversation + Clear + Reply + Attachments + Moderation, AttachmentComposerModel
                 (+ Picking: the items picked for one message and every way in; + Upload: AttachmentWork, one item's prepare, ticket and
                 PUTs, holding the model weakly so a closed room cancels and cleans up)), Views (ChatsView (the Chats root:
                 the inbox row over the rooms), ChatView over ChatTranscript (the anchored list) over ChatRowView (one row, drawing its arrival) + MessageArrival (a row's removal transition), MessageBubble + PendingMessageBubble over
                 BubbleContent (quote, gallery and words on the fill), QuoteBlock + QuoteBar + QuoteStack (the quote inside a bubble and
                 the layout that keeps the bubble hugging its words), ReplyPreviewBar (the composer's reply preview), AttachmentMenuButton
                 + CameraPicker, AttachmentStrip (the picked items above the field), AttachmentGallery + DraftGallery + GalleryGrid,
                 ImageAttachmentView + AttachmentTile + LocalImage + AttachmentImageLoad (the one picture-loading state box), VideoAttachmentView +
                 PlayBadge + DurationBadge, FileAttachmentCard + FileCard, AttachmentViewerSheet (the pager over ImageViewerPage and
                 VideoPlayerPage), QuickLookPreview, ConversationList (the Chats list, owning the clear confirmation),
                 MessageComposer, DaySeparator, SystemMessageRow, MessageContextMenu, ChatRoomMenu (the room's menu, its clear item and
                 the shared confirmation))
    People/      Profiles and direct conversations: Models (UserProfile, GroupSummary, UserProfileDestination,
                 StartConversationPayload), Interfaces (UserRepository), Implementations (RemoteUserRepository, MockUserRepository
                 over the group mock's rosters), ViewModels (UserProfileViewModel), Views (UserProfileView, SharedGroupRow,
                 PersonRow (the avatar + name + badge row that opens a profile; MemberRow and ParticipantRow are built on it))
    Tournaments/ Models (Tournament with TournamentFormat and TournamentStatus, TournamentScope, TournamentDestination and
                 DiscoverTournamentsDestination; TournamentEntry + EntryMember + EntryStatus; TournamentMatch + MatchStatus + MatchSlot
                 + MatchSchedule (with the schedule form's proposal) + MatchScheduleDraft (the form's state and what it sends),
                 TournamentStanding, TournamentDetail (with the opponent lookup), TournamentChange (the room's tournament_changed
                 event); TournamentDraft (with its editing init and Rules) and the
                 Create/UpdateTournamentPayloads, CreateEntryPayload and the match payloads; TeamNameIssue (the team-name sheet's rule),
                 MatchScoreDraft (the match sheet's score rules), MatchOutcome (won / lost / drew / undecided per side); TournamentRole,
                 TournamentParticipation (the Participation analogue) and TournamentPermissions (every other rule of the detail: menu, start,
                 invite, report, teams), MatchActions (who may do what with a match); TournamentSchedule
                 (the pure pairings the mock draws; nothing for fewer than two seeds), BracketLayout (pure: round titles, columns and slot
                 heights), RoundRobinStandings (the table, Laurel's tie-breaks); TournamentDetail also carries starting(at:) and
                 settling(_:at:), the start and the settle as the backend's transactions make them, which the mock and the fake both call;
                 TournamentDetailSection, TournamentConfirmation), Interfaces (TournamentRepository, TournamentDraftEditing), Implementations
                 (RemoteTournamentRepository, MockTournamentRepository (+ Entries, + Matches) + MockTournamentFixtures (+ PadelOpen,
                 + Rooms), RemoteTournamentInviteRepository + MockTournamentInviteRepository (the InviteRepository seam over the
                 tournament routes)), Services (TournamentOpener: fetch a tournament by id and push its detail with a match named,
                 behind a tapped match reminder), ViewModels
                 (TournamentList, TournamentDetail (+ Entries, + Matches), CreateTournament, EditTournament), Views (TournamentCard +
                 TournamentStatusChip + TournamentCardList, TournamentTile + TournamentCarousel, DiscoverTournamentsView,
                 GroupTournamentsSegment, TournamentDetailView with TournamentHeader + TournamentFacts, TournamentEntriesSegment +
                 EntryRow, TournamentResultsSegment over BracketView, StandingsTable and MatchList (all drawing MatchCell), MatchSheet
                 + MatchScheduleView (the organiser's time and place), TournamentParticipationControl + TournamentMenu, TeamNameSheet,
                 the Create/Edit sheets over TournamentDraftSheet and TournamentDraftForm (+ Schedule))
    Inbox/       Models (InboxItem with InboxItemKind, InviteStatus, InvitePayload and TournamentInvitePayload (both over the shared
                 InviteAnswer), ReminderPayload, MatchReminderPayload and the captions; InboxPage; InviteAcceptance (a group or a
                 tournament); InboxDestination; InboxTimeline (day chips, unknown kinds hidden)), Interfaces (InboxRepository),
                 Implementations (RemoteInboxRepository, MockInboxRepository + MockInboxFixtures), State (InboxStore, the one source
                 of the caller's inbox), ViewModels (InboxViewModel: accept into a group or a tournament, decline, open the
                 reminder's game or match), Views (InboxView, InboxItemRow (the group invite and game reminder cards) +
                 InboxItemRow+Tournaments (the tournament invite and match reminder cards) over InboxCardParts, InboxRow (the pinned
                 row on Chats))
lilyTests/       Mirrors the above (Changes/, Concurrency/ (with ReleaseAfterCancelTests), Errors/ (with AppErrorCases, every AppError case
                 listed), Foundation/, Preferences/, Shell/, System/ (with SpyLoggerTests), Validation/ and Moderation/ included;
                 Networking/ holds SendFailingWithTests, LostRaceTests, WriteGateTests and CreateFlowTests); Support/ holds fakes
                 (TestDoubles, AuthDoubles, FakeEventRepository, NetworkingDoubles, ChatDoubles, ChatFixtures, RealtimeHarness,
                 StatisticsDoubles, GroupDoubles (with FakeInviteRepository), GroupViewModelDoubles with the shared GroupHarness and the
                 TermsCountingReporter every harness uses, InboxDoubles, PeopleDoubles, LocationDoubles, PushDoubles, FeedbackDoubles,
                 AttachmentDoubles, CreateEventHarness, EventDetailHarness, FakeTournamentRepository (+ Matches), TournamentHarness), the
                 shared test tools (RequestHold with the HoldsRequests protocol, Recorded, ScriptedAttempt, SpyLogger, TestFixtureFiles,
                 ImageFiles) and fixtures (TestFixtures,
                 GroupFixtures with the groups and invites contract JSON, InboxFixtures with the inbox's, PeopleFixtures with the profile,
                 conversation and participants contract JSON, TournamentFixtures with the tournament, entry, match, standing, room and
                 tournament-note contract JSON, TournamentInboxFixtures with Laurel B3's inbox, accept, invite and room-event JSON;
                 Fixtures/pairings holds the shared pairing fixtures TournamentScheduleTests reproduces)
lilyUITests/     LilyUITestCase (launch + the primitives) + LilyUITestCase+Screens (the screen-reaching helpers), LilySmokeTests, LilySignInTests,
                 LilyGroupsTests (+ Helpers), LilyChatTests (+ Attachments, + Rows), LilyPeopleTests, LilyEventEditTests, LilyLanguageTests,
                 LilyTournamentTests (+ Helpers), LilyDiscoverTests, LilyProfileTests, LilyRosterTests, LilyStateTests, LilyIPadTests: end-to-end
                 walks against the real app in a simulator
scripts/         ci.sh, the single entry point for lint, build and tests; l10n-check.py, the catalog-against-code and InfoPlist check it runs,
                 and test_l10n_check.py, that checker's unittest suite, run first; make-app-icon.swift, the icon renderer
.github/         GitHub Actions workflow and the Dependabot config
```

The Xcode project uses synchronized folder groups: any file added under `lily/`, `lilyTests/` or `lilyUITests/` joins the matching target automatically. The other side of that convenience is that **`lily/` must contain only Swift sources, `Assets.xcassets` and the two string catalogs** — any other file there is copied into the app bundle, and `.gitignore` does not prevent it, because Xcode reads the filesystem rather than the git index.

Rules: interfaces and implementations live in separate folders, constants live under `Config/`, every user-facing error goes through `ErrorCenter`, every log line goes through `Logging`.
