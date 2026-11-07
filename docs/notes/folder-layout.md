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
                 (PushDependencies: the registrar and device repository the data layer chose, EventOpener,
                 PushCoordinator) + AppDependencies+Repositories (Repositories, Auth and the data-layer factories; 2026-11-02)
                 + AppDependencies+Localization (the language store built from the stored choice and the launch arguments)
                 + AppDependencies+Tournaments (the tournament repository and change tracker over the group dependencies; the
                 tournament view-model factories) + AppDependencies+Moderation (the terms sheet's view model) + AppDependencies+Session
                 (the session store settled from the launch arguments; -reset-session decided and logged once as startsFresh and handed to
                 the session, language, currency and filter stores; wireSessionExpiry, the hook that ends the session when the pool
                 refuses to refresh the token) + AppDependencies+Shell (makeShellSync) + AppDependencies+Currency
                 + AppDependencies+Feedback + AppDependencies+Profile (the display name editor's view model over the root's
                 ProfileStore; 2026-10-31) + AppDependencies+LaunchArguments (the value-taking arguments' URL helpers)
  Localizable.xcstrings, InfoPlist.xcstrings   the string catalogs: every line of copy in seven languages, and the usage descriptions
  PrivacyInfo.xcprivacy   the privacy manifest: the two required-reason API categories the app calls (UserDefaults, file timestamps),
                 shipped at the bundle root by the synchronized group (2026-11-01)
  Config/        AppConfig (non-visual constants), AppBranding (product copy, every line read through localized(_:)), DesignTokens (spacing, radii, durations, SF Symbol names),
                 AccessibilityIdentifiers (the identifiers UI tests query); the groups, chat, realtime, moderation, people, shell
                 and language constants, copy, tokens and identifiers live in +Groups / +Chat / +Realtime / +Moderation / +People /
                 +Shell / +Localization / +Settings / +FeatureFlags / +Build (the kind of build: debug, staging, release; 2026-11-01) / +Tournaments / +TournamentResults / +TournamentInvites /
                 +ChatTournaments / +Profile (the display name's limits, copy and identifiers; 2026-10-31) / +Events (map stacking and the place
                 suggestions, 2026-11-06) / +SportMarks (the sport marks' and the map cards' tokens; 2026-11-06) / +EventsMap
                 (the map list's "N events here" header and "+N more" pill; 2026-11-06) / +Polls, +ChatPolls and +ChatPins
                 (the polls' and pins' constants, copy, tokens and identifiers; 2026-10-24) and one `+Area` file per feature beyond these
                 (`ls lily/Config` is the list; 2026-11-02) extension files so SwiftLint's type_body_length never trips on the four main types
  Core/
    Auth/        Models (AuthUser, AuthSession + StoredSession (guest, signed in, or signing out: a sign-out the pool has not confirmed yet),
                 EmailAuthResult, ConfirmOutcome, SignUpOutcome, SessionState, AuthProvider), Interfaces (AuthService, SessionStore,
                 IdentityProvider, CognitoClient, AuthTokenProvider, SessionExpiryReporter, SessionObserver),
                 Implementations (CognitoAuthService over AmplifyCognitoClient, the only file importing Amplify, configured
                 from AmplifyConfigurationBuilder; JWTClaims; Mock*, UserDefaults*, SessionIdentityProvider), SessionController
                 (+AccountDeletion: the account-deleted end and its stand-down, as the Interfaces' AccountDeletionSession)
    Changes/     ChangeTracker (observable change counter; one per kind of data, so lists that missed a change reload),
                 ContentFreshness (the shared staleness rules: TTL, change version, caller, coarse position, retry cooldown; .standard
                 over AppConfig.Lists), StoreLoader (the app-lifetime stores' load skeleton: SingleFlight keyed by user +
                 ContentFreshness, a version that moved mid-request loaded once more), ListState (loading / empty / failed / content,
                 what a list segment draws; held content wins over the first load's spinner); Interfaces (ListSnapshotStore +
                 ListSnapshotKey: a list's last answer kept per caller for the first frame of the next launch), Implementations
                 (FileListSnapshotStore under Caches/ListSnapshots in the backend's JSON coding, NoOpListSnapshotStore for mock runs
                 and the lists that are no tab's)
    Concurrency/ Sleep (the injectable pause timers and debounces wait on; systemSleep is Task.sleep), SingleFlight (one run of a
                 load at a time in a task of its own; callers made while it runs join it; the per-user stores' load), DetachedWork (work off the main
                 actor that dies with its caller: the media preparers' one hop), SlotGate (at most N at once, the rest in order, a
                 cancelled waiter handing its slot on: the upload cap), Deadline (two unstructured tasks, the first outcome wins, the loser
                 cancelled but not awaited: the sign-out's caps on the device removal and the statistics flush), HeadStart (work given
                 a head start of at most a timeout before the next step runs, and left to finish: Explore's lists and the position lookup)
    Foundation/  String+Trimming (trimmed and nonBlankTrimmed, how every typed field is read)
    Realtime/    Interfaces (RealtimeTransport, RealtimeEndpointProvider), Models (RealtimeChannel, RealtimeEnvelope, RealtimeConnectionState,
                 RealtimeTransportError, Backoff + RenewalDelay (the pure reconnect and renewal waits)), Implementations (MockRealtimeTransport: the in-memory bus of a mock run; NoRealtimeTransport;
                 RemoteRealtimeEndpointProvider, FixedRealtimeEndpointProvider), RealtimeSessionController (+Connection, +Routing):
                 the one connection, its rooms, its renewal and the resume protocol
    Navigation/  AppNavigation (selected tab + the Home and Chats stack paths, for pushes made from outside a tab: open(group:) on
                 Home, open(chat:) and openInChat(_:) on Chats; startTab(for:); a SessionObserver, reset on sign-out)
    System/      Pasteboard interface + SystemPasteboard (UIPasteboard), so copying is testable; FileManager+RemoveIfPresent (remove when
                 there, nothing when not, throw when refused); Calendar+NextFullHour (the forms' proposed start, a date on the hour kept);
                 TimeInterval+Units (the hour and the day a fixture or config date is built from)
    Push/        Models (PushEnvironment, DeviceRegistration + payload and removal, LastDeviceRegistration, PushAuthorization,
                 PushPayload + PushTap (what a tapped notification opens: a game, or a tournament's match)), Interfaces (PushRegistrar, DeviceRepository, PushOptIn), Implementations (SystemPushRegistrar over
                 UNUserNotificationCenter and the relay, MockPushRegistrar, RemoteDeviceRepository, MockDeviceRepository,
                 PushEventRelay, NoPushOptIn), PushCoordinator (registration sync, the permission ask, the tapped reminder)
    Errors/      AppError, ErrorMessageMapper (single copy source; the groups, chat, moderation, people, tournament, poll and
                 account-deletion copy in ErrorMessageMapper+Groups / +Chat / +Events / +People / +Tournaments / +Polls /
                 +Profile), ErrorCenter (drives the popup)
    Localization/ AppLanguage (the seven languages, the system's pick), LanguagePreference (system or fixed, a StoredChoice), AppLocale
                 (the process-wide language for lookups and formats; the region read per call), localized(_:) (the one lookup every
                 line of copy goes through), LanguageStore (the user's choice, persisted and published)
    Currency/    CurrencyPreference (system or a fixed ISO code, a StoredChoice; an unoffered stored code reads as system), CurrencyStore
                 (the currency prices are typed in and the price cap is judged in: the Profile choice, else the region's, else EUR)
    Preferences/ Interfaces (StoredChoice: a Profile choice kept in UserDefaults as one string, "system" or its code; ChoiceStore),
                 Implementations (UserDefaultsChoiceStore, the one store behind the language and the currency choices)
    Logging/     Logging facade + OSLogLogger
    Networking/  APIClient interface, APIRequest/APIError models, WireNamedKind (a kind sent as one string, with an unknown case
                 every kind keeps: MessageKind, GroupKind, InboxItemKind, EventType, SkillLevel, AttachmentKind and, since 2026-11-01, TournamentFormat, TournamentStatus, EntryStatus, MatchStatus, MatchSlot, InviteStatus), EmptyBody (NoContent and OptionalBody, the answers of routes that may say nothing),
                 Coordinate+QueryItems (the coarse lat/lon every Explore list sends), Page (the {items, nextCursor} envelope every
                 paged list decodes), URLSessionAPIClient + JSON conventions (queries percent-encoded, refusals logged at warning and
                 faults at error), APIFailureMapping (backend codes to AppError, one exhaustive switch), LostRace (the one TRY_AGAIN
                 repeat every write shares, logging the retry line itself), WriteGate (the frame around one plain write: the repeat,
                 quiet cancellation, the failure logged and reported, a Bool back, a settling read-back), LostAnswer (the read-back
                 after a lost answer every write shares: refetch, apply, landed or not), CreateFlow (the create forms' send: the
                 TRY_AGAIN repeat, the unknown-outcome lookup and ownership check, the update after a reused id)
    Statistics/  Models (Interaction, InteractionKind, FilterSummary, InteractionBatch, InteractionReceipt), the
                 InteractionRecorder interface, RemoteInteractionRecorder (batching) and NoOpInteractionRecorder (mock runs)
    Location/    Coordinate model (+ CoreLocation bridge), LocationFix, PlaceSuggestion (a geocoder offer, 2026-11-06),
                 PlaceMatchPolicy (which geocoded match may stand for a typed place; 2026-11-06),
                 interfaces (LocationService, LocationUpdateSource,
                 GeocodingService (a typed place to a spot and back, 2026-11-05: CoreLocationGeocoder over MapKit's requests,
                 MockGeocodingService deterministic around the fixtures)),
                 implementations (CoreLocation update source and service, caching decorator, mock)
    Validation/  CredentialsValidator (mirroring the backend's @Email: no inner whitespace, one @, a 64-unit local part), String+WireLength
                 (UTF-16 length, as the backend counts text), Collection+FirstOf (the one first-present-issue rule of the forms),
                 String+CodePoints (codePointCount and prefix(codePoints:), the backend's measure of a display name; 2026-10-31)
    UI/          Theme (fonts, aurora role-to-color mapping), Effects (aurora geometry, roles, film grain: pure, testable math;
                 LaunchAnimations, UIKit's animations off until the shell's first frame so the tab bar's pill is placed, not slid),
                 Components (aurora background, content-screen scaffold, glass cards, button modifiers, picker modifiers (lilyMenuPicker; 2026-11-02), FadingPresence (a presence fade; 2026-11-02), provider buttons, error popup,
                 ScreenTitle + ScreenSubtitle, AvatarCircle, SportFill (the sport marks' maroon-to-accent fill and
                 LilyTheme.sportGradient; 2026-11-06), String+Initials (the one initials rule, beside AvatarCircle),
                 UnreadDot, GrowingTextView (the multi-line field the chat composer owns, over a UIKit text view), ConversationRow (avatar + title + caption + dot, shared by the Chats rows and the
                 inbox row), CaptionedTitle (the title-over-captions column the conversation rows and the carousel tiles share; 2026-11-02) and AvatarRowDivider (the divider that starts at their text column), EventTypeChips (the one
                 type-chip flow of the filter, the event form and the group form), EntriesBar (the one "how full" bar; CapacityBar
                 draws an event through it (removed 2026-11-02; `EntriesBar(event:)`)), CapacityMeter (the bar's capsule alone,
                 drawn by EntriesBar and the map card; 2026-11-06), TypeFilterButton + TypeFilterPanel (the type dropdown of both Discover screens), GlassGlyph (a symbol as a mark in the
                 amber glass circle, drawn through AvatarCircle; the preview card's type glyph; removed 2026-11-06), BusyButton (a title with a spinner: join, leave,
                 Message, the tournament controls), TileCarousel + TileLink + TileContent (the group and tournament carousels, swapping to
                 TileGrid on a regular width), CardHeader (the chips-and-time header of the event and tournament cards), OwnerTitleBlock
                 (title, host or organiser line and group line of the two details), ChevronLink (secondary label + .caption2 chevron, the linked line OwnerTitleBlock and HostedInLine draw; 2026-11-01), ValidationHint (accent glyph hidden from accessibility + secondary words, the form footers' hints; 2026-11-01), ListSegment (a list segment's loading / empty / failed
                 / content over ListState), VisibilityChip, DraftSheet (the one sheet around every create and edit form: Cancel, submit,
                 form sizing, own popup) + DraftSubmitButton + CaptionedControl (a caption over a control), SettingsLinkRow
                 (a glass link card: icon, title, subtitle, chevron; Profile's display name and contact rows share it; 2026-10-31),
                 FilterDropdown (FilterDropdownButton + DropdownPanel, the dropdown scaffold of the Discover type filters; Explore's events filter is a form sheet since 2026-11-05), ...), Interfaces
                 (DraftSubmitting: what DraftSheet reads from a form's view model), Layout (LayoutMode, MotionPreference (full or reduced, resolved once from Reduce Motion and read as `\.motion`; 2026-11-01), ReadableColumn, AdaptiveCardGrid,
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
                 loads run; CreateIntent, the keyboard shortcuts' request), Services (ShellSync: the restore (the tab follows through the session observers)
                 and opens a pending notification tap, and the per-user run: account, realtime, Mine, inbox, block list, push, in order,
                 with Explore's lists loading alongside; ShellLists: the Home and Explore list view models the root owns for the app's
                 lifetime, each seeded from its snapshot)
    Events/      Models (SportEvent with optional Price and SkillLevel, EventType and SkillLevel (both keeping a wire value this build does
                 not know as unknown), EventFilter + PersistedEventFilter, DateWindow, Participation, MapFraming + PickerSettlePolicy (the
                 map's opening region; when a settle is the user's choice), EventMapStack (the events on one map spot,
                 one pin; 2026-11-06), MapCardListEdges (whether the map's card list runs past either edge and how
                 many cards wait below; 2026-11-06),
                 EventsPresentation, EventDraft (with its editing init and Rules; the price field's text lives on it) and the
                 Create/UpdateEventPayloads, EventScope with its group case (and the scopes' wire names), EventParticipant, EventLocation
                 (the one distance rule of events, groups and tournaments), PlaceDraft (the shared place validation of the event and
                 tournament drafts), EventListScreenState (Explore's loading / failed / empty / filtered-out / list ladder),
                 CreateIntentPolicy + ExploreSheet (which sheet a create request or a shortcut opens; sign-in for a guest); SportEvent and
                 EventDraft carry an optional EventGroupRef), Interfaces (EventRepository, EventFilterStore, EventDraftEditing),
                 Implementations (remote and mock repositories, MockEventFixtures with the mock's participant names in MockEventFixtures+Participants),
                 ViewModels (list with its filter and freshness extensions, detail with who is in, create, edit), Views (cards, EventCardList (the
                 bare card list), list screen, map, detail with the host's Edit button, ParticipantRow, preview card, EventMapCardList (the
                 selected map stack's scrolling cards, in one glass panel with its header for several, and the "+N more" pill;
                 2026-11-06), filter button and sheet (EventFilterSheet, the full-screen form, 2026-11-05; over SkillLevelPicker, the one level picker), create button, the Create/Edit sheets (thin wrappers over
                 EventDraftSheet, itself a thin wrapper over the shared DraftSheet around the generic EventDraftForm, whose +Place file holds the Where
                 section with the geocoder's suggestions), PlaceFields (the
                 place name plus the PlacePickerRow of the event, group, tournament and match-schedule forms), PriceAmountField (the
                 one decimal-pad price field of the filter sheet's cap and the form's price), location picker, EventLocationMap (the detail's pinned
                 spot, 2026-11-05)), Services (EventOpener: fetch a game by id and push its detail, shared
                 by the inbox's reminder card and a tapped notification; PlaceResolver: fills the missing half of a draft's
                 place through the geocoder on submit, 2026-11-05)
    Profile/     Guest and signed-in profile; Interfaces (ProfileRepository: GET and PUT /api/profile, the name or the bio;
                 ProfileFieldDraft, what the two editors' drafts share), remote and mock implementations, Models (Profile with
                 its bio, ProfileUpdateRequest with one field per request, DisplayNameDraft and AboutDraft with their issues),
                 State (ProfileStore: the caller's name and bio, loaded once per session, cleared with it), ViewModels
                 (ProfileFieldViewModel<Draft>, as DisplayNameViewModel and AboutViewModel; DeleteAccountViewModel, the delete
                 flow's state machine), Views (ProfileView, SettingsScreen (the pushed
                 settings: language, currency, contact, the legal links, Sign out, Delete account; 2026-11-07), DeleteAccountSheet
                 (the delete flow: summary, destructive confirm, locked wait, one-time acknowledgment), DisplayNameRow
                 and DisplayNameSheet, AboutRow and AboutSheet, the Language and Currency rows, SettingsChoiceRow (the popover
                 card the Language and Currency rows share)) (updated 2026-11-07)
    Feedback/    The contact form: Models (FeedbackKind, FeedbackDraft with its issues and the one payload builder,
                 FeedbackEnvironment: app version, OS version, device model, language), FeedbackRepository interface, remote
                 (POST /api/feedback) and mock implementations, FeedbackViewModel, Views (FeedbackRow on Settings and the guest profile, FeedbackSheet)
    Moderation/  The terms sheet: ViewModels (TermsViewModel: shown while a signed-in caller owes the terms, accept, sign out), Views
                 (TermsSheet, presented by AppRootView; since 2026-11-07 also the terms-pending way into DeleteAccountSheet);
                 the report sheet and the moderation repository stay under Groups
    Groups/      Groups, invites, the account and moderation: Models (SportGroup with GroupKind and Counterpart (a direct
                 conversation is a group of kind direct), GroupMember,
                 GroupMembership, GroupVisibility, MemberRole, GroupAccess, GroupDraft and the create/update payloads, GroupScope (with
                 the Discover query's searchPrefix), GroupDetailSection, GroupConfirmation (the detail's leave / delete / remove / ban
                 dialogs), InviteCandidate (with its source and caption), SentInvite (with the
                 send payload; into a group or a tournament), InviteTarget (what the invite sheet invites into), EventGroupRef, MembershipChange, RoomSubscription, GroupDetailContext,
                 Account, DeletionPlan (+ DeletionSettle, the delete flow's landed check),
                 Report models), Interfaces (GroupRepository, InviteRepository, MeRepository, ModerationRepository, GroupDraftEditing),
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
    Chat/        Interfaces (ChatRepository, ChatHistoryCache, AttachmentUploader, AttachmentCache, MediaPreparer, GalleryItem, FrameClock), Models (ChatMessage,
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
                 SystemRowLinks + LinkedContent, which remembers what is gone) and SystemRowDestination (where a tapped one leads), ViewerGeometry + TileGeometry +
                 ViewerLayer (pure: where the moving picture is at each moment and which side of the composer line a layer draws),
                 MovingPicture (the picture on its way), Poll + PollOptionDisplay (a poll message and how an option draws) and
                 PinnedMessage + PinnedBarPosition (the room's pins and where the bar sits; 2026-10-24)), Implementations (RemoteChatRepository, MockChatRepository
                 (+ Attachments + Polls) + MockChatFixtures (+ Polls), InMemoryChatHistoryCache, URLSessionAttachmentUploader, DiskAttachmentCache (+ AttachmentCacheFiles, the
                 byte-moving steps off the main actor), DeviceMediaPreparer over ImagePreparer (+ ImageEncoding), VideoPreparer (+ VideoEncoding)
                 and FilePreparer (+ FileCopying), all off the main actor through DetachedWork, MockMediaPreparer (the picker stand-in), MockAttachmentStore + MockAttachmentURLProtocol,
                 MockAttachmentUploader, DisplayLinkFrameClock: the FrameClock on Core Animation's display link), Services (ChatCatchUp: the REST catch-up shared by the chat and the realtime controller;
                 ChatHistoryClearer: the per-side clear; AttachmentLoader (+ Files): cache first, else one download with the link refreshed
                 and its progress reported, and the named preview file QuickLook and the player read; ReadMarkerFlusher: the read marker's
                 timing; ImageFile: the one decode of a picture file for a view, capped at the header and downsampled to the side the
                 view needs, the upload side downsampling through it too), State (UnreadCenter, ChatOutbox: every room's unsent and failed bubbles, ViewerHero: what the tiles,
                 the viewer and the composer share for the viewer's moves, ViewerMoveDriver: the moves a frame at a time on a FrameClock), ViewModels
                 (ChatViewModel + History + Send + Live + Events + Conversation + Clear + Reply + Attachments + Moderation + Pins + Polls, AttachmentComposerModel
                 (+ Picking: the items picked for one message and every way in; + Upload: AttachmentWork, one item's prepare, ticket and
                 PUTs, holding the model weakly so a closed room cancels and cleans up)), Views (ChatsView (the Chats root:
                 the inbox row over the rooms), ChatView over ChatTranscript (the anchored list) over ChatRowView (one row, drawing its arrival) + MessageArrival (a row's removal transition), MessageBubble + PendingMessageBubble over
                 BubbleContent (quote, gallery and words on the fill), QuoteBlock + QuoteBar + QuoteStack (the quote inside a bubble and
                 the layout that keeps the bubble hugging its words), ReplyPreviewBar (the composer's reply preview), AttachmentMenuButton
                 + CameraPicker, AttachmentStrip (the picked items above the field), AttachmentGallery + DraftGallery + GalleryGrid,
                 ImageAttachmentView + AttachmentTile + LocalImage + AttachmentImageLoad (the one picture-loading state box), VideoAttachmentView +
                 PlayBadge + DurationBadge, FileAttachmentCard + FileCard, AttachmentViewerSheet (the pager over ImageViewerPage and
                 VideoPlayerPage; + Motion for its moves), ViewerMovingPicture (the moving picture, one Canvas per layer), ViewerBackdrop (the black of one layer; 2026-11-02), ViewerStage (the
                 chat's half under the composer), ViewerHeroSource, ViewerDismissPan, QuickLookPreview, ConversationList (the Chats list, owning the clear confirmation),
                 MessageComposer, DaySeparator, SystemMessageRow, MessageContextMenu, ChatClearMenuItem (the Chats rows' clear item and its
                 confirmation; the room's own menu was removed 2026-11-03), PollBubble + PollOptionPill + PollComposerSheet + PollVotersSheet (polls; 2026-10-24), PinnedBar +
                 ChatTranscript+Pins (the pinned bar over the transcript), ChatTranscript+Scrolling, BubbleInk (the ink colour a bubble's small
                 text reads in; 2026-10-27, reworked 2026-11-01), RowReveal, TranscriptWidth, ChatsSplitView (the Chats tab on a regular width; 2026-10-08))
    People/      Profiles and direct conversations: Models (UserProfile with its bio and shared lists, GroupSummary, EventSummary,
                 TournamentSummary, UserProfileDestination, StartConversationPayload, Tombstone (the deleted-account name and
                 mark, 2026-11-07)), Interfaces (UserRepository), Implementations
                 (RemoteUserRepository, MockUserRepository over the group, event, tournament and profile mocks, MockUserFixtures
                 (the fixture bios)), ViewModels (UserProfileViewModel), Views (UserProfileView, SharedGroupRow, SharedHistoryRows
                 (SharedEventRow and SharedTournamentRow), PersonRow (the avatar + name + badge row that opens a profile; MemberRow
                 and ParticipantRow are built on it)) (updated 2026-11-04)
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
                 (TournamentList, TournamentDetail (+ Actions, + Entries, + Matches), CreateTournament, EditTournament), Views (TournamentCard +
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
lilyTests/       Mirrors the above (Changes/, Concurrency/ (with ReleaseAfterCancelTests and HeadStartTests), Errors/ (with AppErrorCases, every AppError case
                 listed), Foundation/, Preferences/, Shell/, System/ (with SpyLoggerTests), Validation/ and Moderation/ included;
                 Profile/ holds ProfileStoreTests and ProfileStoreBioTests, DisplayNameViewModelTests, AboutViewModelTests,
                 DisplayNameDraftTests, AboutDraftTests and both repositories' tests (2026-11-04); Networking/ holds SendFailingWithTests, LostRaceTests, WriteGateTests, LostAnswerTests, CreateFlowTests and WireNamedKindTests; Realtime/ holds RealtimeRoomCompactionTests and Tournaments/ TournamentUnseenValuesTests beside the suites at their limits (2026-11-01); Errors/ BackendErrorCodeTests, Realtime/ RealtimeMembershipChangeRoutingTests and Tournaments/ MockTournamentRefusalsTests+Caps the same way (2026-11-02); App/ holds PrivacyManifestTests beside the AppDependencies suites, Chat/ MessageArrivalTests and UI/ MotionPreferenceTests (2026-11-01); Events/ holds CreateEventOutcomeTests beside CreateEventViewModelTests since 2026-11-01, and MapCardListEdgesTests since 2026-11-06, with CreateEventPlaceTests, EditEventPlaceTests and EventDraftPlaceTests from the 2026-11-06 pre-merge review; Location/ holds PlaceSuggestionTests since then); Support/ holds fakes
                 (TestDoubles, AuthDoubles, FakeEventRepository, NetworkingDoubles, ChatDoubles, ChatFixtures, RealtimeHarness, ShellDoubles,
                 StatisticsDoubles, GroupDoubles (with FakeInviteRepository), GroupViewModelDoubles with the shared GroupHarness and the
                 TermsCountingReporter every harness uses, InboxDoubles, PeopleDoubles, LocationDoubles, PushDoubles, FeedbackDoubles,
                 ProfileDoubles (FakeProfileRepository and the Profile fixture), AttachmentDoubles, CreateEventHarness, EventDetailHarness,
                 FakeTournamentRepository (+ Matches), TournamentHarness, PollFixtures and ChatPollDoubles (the poll samples and fakes; 2026-10-24)), the
                 shared test tools (RequestHold with the HoldsRequests protocol, Recorded, ScriptedAttempt, SpyLogger, TestFixtureFiles,
                 ImageFiles) and fixtures (TestFixtures,
                 GroupFixtures with the groups and invites contract JSON, InboxFixtures with the inbox's, PeopleFixtures with the profile,
                 conversation and participants contract JSON, TournamentFixtures with the tournament, entry, match, standing, room and
                 tournament-note contract JSON, TournamentInboxFixtures with Laurel B3's inbox, accept, invite and room-event JSON
                 (an `extension ContractSamples` since 2026-11-02);
                 Fixtures/pairings holds the shared pairing fixtures TournamentScheduleTests reproduces)
lilyUITests/     LilyUITestCase (launch + the primitives) + LilyUITestCase+Screens (the screen-reaching helpers)
                 + LilyUITestCase+Elements (element primitives: text, scroll-and-tap, predicate wait, confirmation taps; 2026-11-02)
                 + MockIDs (the fixture row ids, 2026-11-02), LilySmokeTests, LilySignInTests,
                 LilyGroupsTests (+ Helpers), LilyChatTests (+ Attachments, + Composer, + Polls, + Rows, + Viewer), LilyPeopleTests, LilyEventEditTests, LilyLanguageTests,
                 LilyTournamentTests (+ Helpers), LilyDiscoverTests, LilyProfileTests, LilySettingsTests, LilyRosterTests, LilyStateTests, LilyIPadTests: end-to-end
                 walks against the real app in a simulator
scripts/         ci.sh, the single entry point for lint, build and tests; l10n-check.py, the catalog-against-code and InfoPlist check it runs,
                 and test_l10n_check.py, that checker's unittest suite, run first; make-app-icon.swift, the icon renderer
.github/         GitHub Actions workflow and the Dependabot config
```

The Xcode project uses synchronized folder groups: any file added under `lily/`, `lilyTests/` or `lilyUITests/` joins the matching target automatically. The other side of that convenience is that **`lily/` must contain only Swift sources, `Assets.xcassets` and the two string catalogs** (since 2026-11-01 also `PrivacyInfo.xcprivacy`, see `build-test-and-simulator.md`) — any other file there is copied into the app bundle, and `.gitignore` does not prevent it, because Xcode reads the filesystem rather than the git index.

Rules: interfaces and implementations live in separate folders, constants live under `Config/`, every user-facing error goes through `ErrorCenter`, every log line goes through `Logging`.

Pass of 2026-11-02 (deep-review finding L008): the poll and pin files of 2026-10-24 (Chat Models, Views, ViewModels and Implementations, the Config and ErrorMessageMapper `+Polls` and `+ChatPins` files, the test doubles PollFixtures and ChatPollDoubles under `lilyTests/Support`, the LilyChatTests+Polls, +Composer and +Viewer UI test files) and the Chat Views that had gone unlisted (BubbleInk, RowReveal, TranscriptWidth, ChatsSplitView, ChatTranscript+Scrolling) were added above, each checked against `ls`; the Config enumeration ends in a rule, one `+Area` file per feature, rather than a list completed file by file.

Pre-merge review of 2026-11-06: the Events Views entry now names EventFilterSheet instead of "filter button and panel", and
the place tests added by the review fixes (CreateEventPlaceTests, EditEventPlaceTests, EventDraftPlaceTests,
PlaceSuggestionTests, PlaceMatchPolicyTests) are listed under lilyTests.
