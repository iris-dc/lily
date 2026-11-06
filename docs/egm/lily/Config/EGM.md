# Config

Source: `lily/Config/`

## Overview

Four `nonisolated enum` namespaces, each a root file plus `+Area.swift` files that are `nonisolated extension`s of the
root or of one of its nested enums (64 files, about 3,200 lines). `AppConfig` is the non-visual configuration: API
paths and base URLs, limits mirrored from the Laurel backend, launch-argument literals, feature flags, Cognito ids.
`AppBranding` holds every user-facing string as a computed `static var` or `static func` whose body is
`localized("English text")`, so the English text is the catalog key. `DesignTokens` holds the visual constants and
`AccessibilityIdentifiers` the kebab-case identifiers that `lilyUITests` mirrors by hand. Nothing here keeps state;
the only runtime read is `Bundle.main.bundleIdentifier`. Every feature reads these values; the composition root that wires them is [App](../App/EGM.md).

## Interface

### `AppConfig` (`lily/Config/AppConfig.swift:AppConfig`)

- Namespaces in the root file: `Auth`, `Cognito`, `Storage.Keys`, `Events` (+ `Creation`, `Editing`), `Lists`,
  `Location`, `ErrorPopup`, `Launch`, `API` (+ `Headers`, `Paths`, `Query`), `Statistics`, `LaunchArguments`,
  `Logging`, `Version`. Added by `+Area` files: `Chat` (+ `Attachments`, `Polls`, `Pins`), `Currency`, `DisplayName`
  (`lily/Config/AppConfig+Profile.swift`: `length = 1...32` code points, `backendDefault = "Player"`, both Laurel's
  `profile.*` settings) and `About` (same file: `maxLength = 300` code points, Laurel's `profile.max-bio-length`),
  `Events` extras in `lily/Config/AppConfig+Events.swift` (`mapStackRadiusMeters` 11 (an event joins the first stack
  whose first spot lies within it), `mapStackDecimals` 4 (only names a stack: its first spot rounded),
  `placeSuggestionCount` 3, `placeSuggestionDebounce` 300 ms, `placeSuggestionMinimumQuery` 2,
  `placeSearchRegionMeters` 100,000 (the side of the region the geocoder and the suggestions favour around the draft's
  spot or the user; a hint only, so a city name still lands on the city); 2026-11-06), `Build`, `FeatureFlags`,
  `Feedback`, `Groups`, `Inbox`, `Moderation`, `People`, `Push` (+ `Payload`), `Realtime`, `Tournaments`.
- `API` (`lily/Config/AppConfig.swift:AppConfig.API`): `localBaseURL = http://localhost:8080`,
  `productionBaseURL = https://api.iskra.red`; `baseURL` is `localBaseURL` under `#if DEBUG && targetEnvironment(simulator)`,
  else `productionBaseURL`; `sendsLocalUserHeader` is `true` under `#if DEBUG`; `requestTimeout = 15`,
  `tryAgainDelay = .milliseconds(400)`, `unauthorizedStatus = 401`, `rateLimitedStatus = 429`, `contentTooLargeStatus = 413`
  (a `REQUEST_TOO_LARGE` answer, never an expected refusal), `clientErrorStatuses = 400..<500`, `successStatuses = 200..<300`
  (a delivered request; the API client, the attachment uploader and the attachment loader all judge by it).
  `Headers`: `X-Local-User-Id`, `X-App-Version`, `Authorization`, `Bearer `, `Accept`, `Content-Type`,
  `json = "application/json"`, `Retry-After` (the last added in `AppConfig+Chat.swift`).
  `Query`: `scope`, `lat`, `lon`, `before`, `after`, `q`, `type`, `cursor`, `limit`, `ids`.
- `API.Paths`: roots `/api/events`, `/api/profile`, `/api/interactions`, `/api/groups`, `/api/me/inbox`,
  `/api/me/inbox/read`, `/api/reports`, `/api/blocks`, `/api/me`, `/api/me/terms`, `/api/conversations`,
  `/api/feedback`, `/api/me/devices`, `/api/tournaments`; one `static func` per sub-resource, e.g. `event(id:)`,
  `participants(eventId:)`, `group(id:)`, `groupMembers(id:)`, `messages(id:)`, `message(id:messageID:)`, `read(id:)`,
  `uploads(id:)`, `attachment(id:messageID:attachmentID:)`, `pin(id:messageID:)`, `inboxAccept(id:)`, `block(userID:)`,
  `user(id:)`, `device(token:)`, `tournament(id:)`, `tournamentStart(id:)`, `matchResult(id:matchID:)`, `groupTournaments(id:)`.
- `LaunchArguments` (`lily/Config/AppConfig.swift:AppConfig.LaunchArguments`): `isHonored` is `true` under `#if DEBUG`;
  `flagPrefix = "-"`. Flags: `-reset-session`, `-mock-location`, `-start-as-guest`, `-mock-auth`, `-mock-auth-confirm`,
  `-mock-auth-fail`, `-mock-events`, `-mock-events-fail`, `-hold-popups`, `-freeze-aurora`, `-mock-attachment-picker`,
  `-mock-chat-replies`, `-mock-terms-pending`, `-system-push`. Value-taking: `-api-base-url`, `-mock-user-id`,
  `-app-language`, `-realtime-endpoint`. `static func value(following: String, in: [String]) -> String?`;
  `static func appLanguage(from: [String]) -> AppLanguage?` (`lily/Config/AppConfig+Localization.swift`).
- `FeatureFlags` (`lily/Config/AppConfig+FeatureFlags.swift:AppConfig.FeatureFlags`): `groups`, `chat`, and
  `tournaments` (`lily/Config/AppConfig+Tournaments.swift`) are `true` under `#if DEBUG || STAGING`, else `false`.
- `Build` (`lily/Config/AppConfig+Build.swift:AppConfig.Build`): `enum Configuration: Sendable { debug, staging, release }`;
  `static let configuration` is `.debug` under `#if DEBUG`, `.staging` under `#elseif STAGING`, else `.release`: the one
  place that names the kind of build (Debug and Staging run from Xcode development-signed, Release alone is archived).
- `Cognito`: `region = "eu-central-1"`, `userPoolId = "eu-central-1_JmfE31ODT"`, `appClientId = "54dul3essertek166u2st78s4a"`,
  `confirmationCodeLength = 6`, `localeMetadataKey = "locale"`. `Auth`: `minimumPasswordLength = 8`,
  `mockConfirmationCode = "123456"`, `emailLocalPartMaxLength = 64` (`lily/Config/AppConfig+Validation.swift`).
- `Storage.Keys`: `lily.session.stored`, `lily.language.preference`, `lily.events.filter`, `lily.currency.preference`;
  `previewSuitePrefix = "lily.preview."`. `Logging.subsystem = Bundle.main.bundleIdentifier ?? "iris.lily"`. `Version`:
  `CFBundleShortVersionString`, `CFBundleVersion`. `Launch.animationsResumeFallback = 3`. `ErrorPopup.autoDismissDelay = .seconds(4)`.
- `Events`: `filterRadiiMeters = [2_000, 5_000, 10_000, 25_000]`, `defaultFilterRadiusMeters = 10_000`,
  `defaultFilterDateSpanDays = 7`, `positionPrecision = 2`, `nearlyFullRatio = 0.75`. `Creation`: `titleMaxLength = 80`,
  `locationNameMaxLength = 120`, `descriptionMaxLength = 1000`, `lookingForMaxLength = 300`, `capacityRange = 2...200`,
  `minimumLeadTimeMinutes = 15`, `priceLimitExclusive = 10_000_000`. `Editing`: `startMargin = 60`, `minimumLeadTime = 0`.
- `Lists`: `staleAfter = 60`, `retryAfterFailure = 10`, `snapshotDirectoryName = "ListSnapshots"`, `snapshotFormat = 2`,
  `snapshotFormatFileName = "format"`, `guestSnapshotName = "guest"`, the snapshot names (`events-upcoming`,
  `events-joined`, `tournaments-upcoming`, `tournaments-mine`, `groups-mine`, `groups-discover`, `profile`,
  `groupEventsSnapshot(_:)`, `groupTournamentsSnapshot(_:)`). `Location`: `mockCenter = Coordinate(52.5200, 13.4050)`,
  `fixTimeout = .seconds(8)`, `firstFixWait = .seconds(1.5)`, `fixTTL = .seconds(300)`, `failedFixTTL = .seconds(30)`.
  `Statistics`: `batchSize = 10`, `flushDelay = .seconds(30)`, `maxBuffered = 100`, `maxFilterTypes = 32`.
- `Chat` (`lily/Config/AppConfig+Chat.swift:AppConfig.Chat`): `messageMaxLength = 2000`, `historyPageSize = 50`,
  `catchUpPageSize = 200`, `maxCatchUpPages = 3`, `roomCacheLimit = 300`, `readMarkFlushInterval = 60`,
  `replyExcerptLength = 120`, `rateLimitCooldownFallback = 10`. `Chat.Attachments` (`lily/Config/AppConfig+Attachments.swift`):
  `maxPerMessage = 10`, `imageMaxBytes = 10 MiB`, `imageMaxDimension = 2048`, `imageMaxDeclaredPixels = 16_000_000` (a
  stored picture whose header declares more is not decoded), `imageContentType = "image/jpeg"`,
  `videoMaxBytes = 50 MiB`, `videoMaxDurationSeconds = 180`, `videoExportPreset = AVAssetExportPreset1280x720`,
  `fileMaxBytes`, `directVideoMaxBytes` and `directFileMaxBytes = 40 MiB`, `diskCacheBytes = 200 MiB`,
  `maxConcurrentUploads = 2`, `uploadTimeout = 120`. `Chat.Polls`: `questionMaxLength = 255`, `optionMaxLength = 100`,
  `minOptions = 2`, `maxOptions = 10`; `Chat.Pins.maxPins = 50` (`lily/Config/AppConfig+Polls.swift`).
- `Groups` (`lily/Config/AppConfig+Groups.swift`): `nameLength = 3...60`, `descriptionMaxLength = 500`,
  `locationNameMaxLength = Events.Creation.locationNameMaxLength`, `maxMembers = 500`, `maxMemberships = 50`,
  `discoverPageSize = 50`, `searchDebounce = .milliseconds(300)`, `queryMaxLength = 40`. `Tournaments`
  (`lily/Config/AppConfig+Tournaments.swift`): `nameLength = 3...60`, `teamSizeRange = 1...11`, `teamNameLength = 2...40`,
  `entriesRange = 2...64`, `maxEntriesRoundRobin = 12`, `minEntriesRoundRobin = 3`, `maxOrganizedOpen = 10`,
  `maxPerUser = 20` (both count open tournaments only, in registration or in progress; finished and cancelled ones
  never count, as Laurel's `tournaments.max-per-user` says), `scoreRange = 0...999`;
  `maxEntries(for:)`, `minEntries(for:)`, `entriesRange(for: TournamentFormat) -> ClosedRange<Int>` (an unknown
  format takes single elimination's bounds; Laurel validates the real ones).
- Smaller areas: `Inbox.pageSize = 50`; `Moderation` (`commentMaxLength = 500`, `maxBlocks = 500`,
  `supportEmail = "support@iskra.red"`, `termsURL` and `privacyURL` = `API.productionBaseURL.appending(path:)` `terms` / `privacy`); `People.maxConversations = 200`, `People.maxSharedHistory = 20` (Laurel's `profile.max-shared-history`); `Feedback`
  (`messageMaxLength = 2000`, `replyEmailMaxLength = 254`, `detailMaxLength = 80`); `Currency` (`defaultCode = "EUR"`,
  `offered`, 14 codes); `Push` (`reregisterInterval = 24 * 60 * 60`, `tokenTimeout = .seconds(10)`, `platform = "ios"`,
  `redactedToken = "<token>"`, `Payload` keys `kind`, `eventId`, `event_reminder`, `match_reminder`, `tournamentId`,
  `matchId`); `Realtime` (`productionEndpoint: URL? = nil`, `reconnectBackoffSeconds = [1, 2, 4, 8, 16, 30]`,
  `maxReconnectsWithoutToken = 8`, `maxRoomSubscriptions = 10`, `maxConnectionAge = 21_600`, `mockEndpoint = mock://realtime`).

### `AppBranding` (`lily/Config/AppBranding.swift:AppBranding`)

- Root: `static let name = "iskra"`, the shared actions `done` and `remove`, the landing, sign-in, tab-title and
  event-detail strings (`landingPrimaryAction`, `signInAction`, `homeTitle`, `exploreTitle`, `profileTitle`, `joinAction`,
  ...); `signInButtonTitle(for:)`, `passwordHint(minimumLength:)`, `confirmEmailSubtitle(email:)`, `hostedByTitle(for:)`;
  `chatsTitle` lives in `AppBranding+Inbox.swift`.
- Nested namespaces: `Home`, `Events` (+ `Filter`, `Create`, `Edit`), `Chat` (+ `Attachments`, `Pins`, `Polls`),
  `Groups` (+ `Create`, `Invite`), `Chats`, `Inbox`, `Intro` (+ `Chat`), `Feedback`, `DisplayName`, `About`
  (`lily/Config/AppBranding+Profile.swift`: `title`, `subtitle`, `defaultSubtitle`, `placeholder`, `footer`, `save`,
  `tooLong(limit:)`), `Moderation`, `Forms` (`close`,
  `back`, `cancel`), `People`, `Settings`, `Tournaments` (+ `Create`, `Schedule`, `Match`, `Standings`).
- Representative functions: `Events.spotsLeft(_:)`, `Events.joined(_:of:)`, `Events.Create.capacity(_:needed:)`,
  `Events.Create.name(for: PlayerLimit)`, `Events.Create.message(for: EventDraft.Issue)`, `Events.Create.coordinateText(_:)`,
  `Groups.members(_:)`, `Groups.caption(_:)`, `Groups.Create.message(for: GroupDraft.Issue)`, `Chat.replyingTo(_:)`,
  `Chat.Pins.pinnedMessage(_:of:)`, `Chat.Polls.voterCount(_:)`, `Chat.tournamentStarted(format:)`,
  `Inbox.invitedYou(inviter:group:)`, `Intro.headline(for: IntroSlide) -> [String]`, `People.name(_:isSelf:)`,
  `Tournaments.entries(_:of:teamSize:)`, `Tournaments.Create.message(for:format:)`, `Tournaments.Match.score(_:_:)`,
  `Tournaments.Match.status(_: MatchStatus)`, `Feedback.tooLong(limit:)`, `Moderation.blockConfirmationTitle(name:)`.
- The map's selected-stack list (2026-11-06), both in `lily/Config/AppBranding+EventsMap.swift`:
  `Events.eventsHere(_:)` ("%lld events here", plural in the catalog, the panel's header beside the place's name;
  `lily/Config/AppBranding+EventsMap.swift:AppBranding.Events.eventsHere(_:)`) and `Events.moreBelow(_:)` ("+%lld
  more", the pill under the cards while some wait below;
  `lily/Config/AppBranding+EventsMap.swift:AppBranding.Events.moreBelow(_:)`).
- The one helper every string goes through: `nonisolated func localized(_ key: String.LocalizationValue) -> String`
  (`lily/Core/Localization/Localized.swift:localized`); a `\(count)` interpolation becomes the catalog's `%lld` or `%@`.

### `DesignTokens` (`lily/Config/DesignTokens.swift:DesignTokens`)

- Nested enums: `Spacing` (`xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`, `xxl 32`), `Radius` (`md 16`, `card 22`, `bubble 18`,
  `quote 10`, `screen 32`, `pollPill 14`), `Duration` (`fast 0.2`, `normal 0.35`, `slow 0.6`, `viewerTransition 0.28`),
  `Layout` (`screenMargin = Spacing.lg`, `detailMargin = Spacing.xl`, `fieldHeight 50`, `controlHeight 44`, `popupMaxWidth 520`;
  iPad `wideMinWidth 1000`, `readableWidth 720`, `cardMinWidth 340`, `cardMaxWidth 520`, `chatsSidebarIdealWidth 360`),
  `Opacity` (`glassTint 0.22`, `secondaryOnAccent 0.82` in `+Polls.swift`, white at which reads 4.66:1 on the accent,
  `pressedTextButton 0.6` in `+Layout.swift`, ...), `Aurora` (`landingIntensity 0.85`, `contentIntensity 0.55`, `frameInterval 1/30`,
  `revealDuration 3.5`, `driftPeriods [19, 23, 29, 37]`, `driftWeights [0.5, 0.3, 0.2]`, `grainSeed 0x4C69_6C79`),
  `Typography` (`headlineSize 44`, `headlineTracking -1.8`, `titleTracking -0.5`), `Symbols` (SF Symbol names:
  `home = "house"`, `explore = "binoculars"`, `game = "calendar"`, `profile = "person"`, `groups = "person.3"`,
  `tournament = "trophy"`, ...), `MessageArrival` (`+Groups.swift`), `TabBar.symbolWeight: UIImage.SymbolWeight = .light`
  (`lily/Config/DesignTokens+Shell.swift`).
- Sport marks and the map's cards (`lily/Config/DesignTokens+SportMarks.swift`, 2026-11-06): `Layout.sportGlyphFraction
  0.46`, `sportMarkGlowRadius 4`, `sportMarkRimWidth 0.5`, `chipMarkSize 16`, `mapCardMarkSize 44`,
  `mapCardMeterWidth 28`, `mapCardTitleLines 2`, `mapCardListFade 56`, `mapCardVisibleShare 0.01` (any sliver of a
  card in view counts it as seen, so a card taller than the list at accessibility sizes still counts and the pill names
  only the whole cards after the last one showing), `mapCardListUnmeasuredHeight 1` (the card list's height before its
  first measurement; a zero-height scroll view never lays out its cards to report one), `mapCardEdgeSlack 1` (scroll-geometry rounding that does
  not mean more beyond an edge), `mapMorePillEntryScale 0.8`; `Opacity.sportMarkGlow 0.45`, `sportMarkRim 0.18`,
  `sportGlassTint 0.55`, `mapCardCapsuleFill 0.1`, `mapPanelCardWash 0.07` (the ink wash of a card inside the
  many-events panel, instead of a second glass); `Symbols.moreBelow = "chevron.down"`
  (`lily/Config/DesignTokens+SportMarks.swift:DesignTokens.Layout`). In `DesignTokens.swift`,
  `Layout.mapCardListMaxHeight` is 400 (about three and a half of the two-row cards; 352, about five one-row cards,
  until 2026-11-06) beside `mapSelectedCardWidth 340` and `pressedCardScale 0.97`.
- Non-scalar members: `Symbols.fileGlyphs: [(type: UTType, symbol: String)]` (8 entries),
  `Duration.viewerFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)`,
  `Duration.viewerTransitionCurve` and `viewerThrowCurve: UnitCurve` (`lily/Config/DesignTokens+Attachments.swift`),
  `Layout.introScreenTypeSize: DynamicTypeSize = .xSmall`, `Layout.multilineFieldLines = 1...5`, `Layout.aboutFieldLines = 3...8`, `Layout.settingsSubtitleLines = 2`,
  `Layout.feedbackMessageLines = 4...10`. No `Color`, `Font`, `Image` or generated asset symbol in the family.

### `AccessibilityIdentifiers` (`lily/Config/AccessibilityIdentifiers.swift:AccessibilityIdentifiers`)

- Kebab-case, area-prefixed `static let` literals: root (`events-filter`, `create-submit`, `auth-email`, ...),
  +Groups (`chat-list`, `chat-composer`, `create-group`, ...), +Tournaments (45 literals and 6 builders, e.g. `match-score-a`), +Polls,
  +Attachments, +Inbox, +Feedback, +Moderation, +People (`profile-message`, `profile-bio`, `sharedEventRow(_:)`),
  +Profile (`profile-name`, `profile-name-field`, `profile-name-save`, `profile-name-cancel`, `profile-about`,
  `profile-about-field`, `profile-about-save`, `profile-about-cancel`), +Currency, +Layout, +Landing (`intro-pager`), +Localization.
- Builders: `filterType(_: EventType)` (`filter-type-<wireName>`), `createPlaceSuggestion(_ index: Int)`
  (`create-place-suggestion-<index>`), `introSlide(_: IntroSlide)`, `groupRow(_:)`,
  `message(clientID:)` (`message-client-<id>`), `message(id:)`, `messageQuote(id:)`, `memberRow(_:)`, `inviteCandidate(_:)`,
  `inviteSend(_:)`, `inboxItem(_:)`, `inboxAccept(_:)`, `inboxDecline(_:)`, `participantRow(_:)`, `pollOptionField(_: Int)`,
  `pollOption(_: Int)`, `chatAttachment(clientID:)`, `chatAttachmentRemove(clientID:)`, `messageAttachmentImage(id:)`,
  `messageAttachmentVideo(id:)`, `messageAttachmentFile(id:)`, `tournamentRow(_:)`, `entryRow(_:)`,
  `tournamentJoinTeam(_:)`, `match(_:)`, `matchWalkoverWinner(_:)`, `standing(_:)`.

## Invariants

- Every top-level declaration in all 64 files is `nonisolated`: the four root enums and every `extension`
  (`grep -c nonisolated` is 33 across the 12 `DesignTokens*` files and 1 in each `AccessibilityIdentifiers*` file;
  `grep "^extension\|^enum\|^struct" lily/Config/AppBranding*.swift` returns nothing). No `Sendable`, `@MainActor` or
  other isolation annotation appears in the directory.
- `AppConfig` is only `static let` constants and pure `static func` builders (`lily/Config/AppConfig.swift:AppConfig`).
  `baseURL` is local only under `#if DEBUG && targetEnvironment(simulator)`; `sendsLocalUserHeader` and
  `LaunchArguments.isHonored` are `true` only under `#if DEBUG`; the three `FeatureFlags` are `true` only under
  `#if DEBUG || STAGING`; `Build.configuration` is `.release` only when neither `DEBUG` nor `STAGING` is set.
  `LaunchArguments.value(following:in:)` returns `nil` when the flag is absent, is last, or the
  next argument starts with `flagPrefix`: a prefixed argument is a flag, never a value.
- Limits mirror Laurel's, counted in UTF-16 units, so a draft that passes here never earns a 400: `Events.Creation`,
  `Chat.Attachments` (every image leaves as JPEG, every video as `video/mp4` at 1280x720), `Chat.Polls`,
  `Chat.replyExcerptLength = 120`, `Auth.emailLocalPartMaxLength = 64`, `Statistics.maxFilterTypes = 32` (Laurel's
  `FilterSummaryDto.MAX_TYPES`); `Groups.locationNameMaxLength` aliases `Events.Creation`'s (`lily/Config/AppConfig+Groups.swift`).
- `Tournaments.entriesRange(for:)` is always `minEntries(for:)...maxEntries(for:)`: single elimination and an unknown
  format `2...64`, round robin `3...12` (`lily/Config/AppConfig+Tournaments.swift`). `Chat.tournamentStarted(format:)`
  answers the generic "The tournament started" for `nil` and for an unknown format; `Tournaments.Match.status(_:)`
  answers an unknown status's raw name (`lily/Config/AppBranding+ChatTournaments.swift`,
  `lily/Config/AppBranding+TournamentResults.swift`). `Lists.snapshotFormat = 2`: a directory written under
  another number is swept. `Realtime.productionEndpoint` stays `nil` until the stack is deployed; in debug the
  `-realtime-endpoint` argument decides. `Push.redactedToken` stands in for the device token in log lines.
  `URL(string:)!` is force-unwrapped on literals only (`API.localBaseURL`, `API.productionBaseURL`, `Moderation.supportURL`,
  `Realtime.mockEndpoint`); `termsURL` and `privacyURL` are appended to `API.productionBaseURL`. The `/api/me` routes derive from
  `Paths.me` (`inbox`, `inboxRead`, `devices`, `meTerms`), as every nested path derives from its parent.
- `AppBranding`: every localized member is a computed `static var` or a `static func`, never `static let`; the eight
  `static let`s are non-localized constants (`name`, `Events.separatorGlyph = "·"`, `Events.captionSeparator`,
  `Events.Create.coordinateFormat = "%.4f, %.4f"`, `Inbox.title`, `Tournaments.Match.scoreSeparator = "–"`,
  `Tournaments.Standings.rank = "#"`, `Standings.difference = "+/-"`) (`lily/Config/AppBranding.swift:AppBranding`).
  `coordinateText(_:)` uses `String(format:)` and is never localized, since a localized decimal comma would collide
  with the separator.
- Role keys: the same English word in another grammatical role gets a parenthesised key with its own catalog entry:
  `"Any (price)"` (`AppBranding.Events.Filter.anyPrice`), `"Message (verb)"` (`AppBranding.People.message`),
  `"Not allowed (draws)"` (`AppBranding.Tournaments.Create.drawsNotAllowed`). Shared one-word actions (`done`, `remove`)
  are declared once at the root and aliased by the feature namespaces, so each is one catalog key. Caption parts are
  joined with `Events.captionSeparator` through `Groups.caption(_:)` (`lily/Config/AppBranding+Groups.swift`), the
  token's only `joined(separator:)` consumer (`PollBubble`, `FeedbackEnvironment` and `EventPreviewCard` call the
  joiner since 2026-11-02; `EventPreviewCard` no longer since 2026-11-06,
  its facts are separate views; `PlaceLine` draws the bare `separatorGlyph`).
  `Events.Create` has no `cancel` alias: every sheet reads `Forms.cancel`.
- Validation copy never hard-codes a limit: `Events.Create.message(for:)`, `Groups.Create.message(for:)`,
  `Tournaments.teamNameMessage(for:)` and `Tournaments.Create.message(for:format:)` interpolate `AppConfig` values; the
  `valueMessage` helpers end in `default: ""`. The hints shared by the three forms and the contact sheet are declared once in
  `AppBranding.Forms` (`nameTooLong(limit:)`, `descriptionTooLong(limit:)`, `placeNameMissing`, `placeNameTooLong(limit:)`,
  `startTooSoon(minutes:)`, `tooLong(limit:)`; `lily/Config/AppBranding+Forms.swift`) and `Feedback.kindContact` aliases
  `Chat.Polls.question`, so every catalog key has one declaration. `+Capacity`, `+Intro`, `+TournamentInvites` and
  `+TournamentResults` split `AppBranding` and `AppBranding.Tournaments` under SwiftLint's type-body limit.
- `DesignTokens` aliases keep one source: `Layout.tournamentTileWidth = groupTileWidth`, `Symbols.currency = Symbols.price`. `Symbols.fileGlyphs` is ordered,
  first match wins, `Symbols.file` for the rest. `Aurora.driftPeriods` are pairwise incommensurate, `driftWeights` sum
  to one, `grainSeed` is deterministic so every launch and test sees the same grain (`lily/Config/DesignTokens.swift:DesignTokens.Aurora`).
  `TabBar.symbolWeight` exists because the iOS 26 tab bar ignores `symbolVariants` and `fontWeight`.
- A UI test that reads an `AccessibilityIdentifiers` literal mirrors it by hand in `lilyUITests` (as it does the launch arguments): a rename
  here must be repeated there (`lily/Config/AccessibilityIdentifiers.swift:AccessibilityIdentifiers`). Only `introPager`
  is mirrored from +Landing; the report sheet's reason rows and the feedback kind picker carry no identifiers and are
  found by label; the inbox's "Load earlier" button, the profile's shared-group rows container and the owner line of an
  event's and a tournament's title carry none either (no test read them); the event Edit sheet reuses the create identifiers; `createGroup` is the group row of both the event
  and the tournament form; `message(clientID:)` is stable across the optimistic-to-stored swap.

## Side Effects

- `AppConfig.Logging.subsystem` reads `Bundle.main.bundleIdentifier` at static initialisation (fallback `"iris.lily"`):
  the only runtime environment read in the directory (`lily/Config/AppConfig.swift:AppConfig.Logging`).
- Every `AppBranding` member performs a catalog lookup at access time: `localized(_:)` reads the process-global
  `AppLocale.current` and calls `String(localized:bundle:locale:)` (`lily/Core/Localization/Localized.swift:localized`).
  No file in the directory touches `Locale`, `UserDefaults`, `FileManager`, `ProcessInfo`, `CommandLine`, `Date()` or a formatter.
- `DesignTokens` and `AccessibilityIdentifiers`: none; `TabBar.symbolWeight` is an enum case, not a built `UIImage`.
  `#if DEBUG`, `#if DEBUG && targetEnvironment(simulator)`, `#if DEBUG || STAGING` and `Build`'s
  `#if DEBUG` / `#elseif STAGING` / `#else` select values at build time only.

## Verification

- Run: `./scripts/ci.sh unit` (suites `lilyTests/Config/AppBrandingTests.swift`, `GroupsConfigTests.swift`, `LaunchArgumentsTests.swift`).
- Run: `./scripts/ci.sh lint` (`scripts/l10n-check.py` checks every `localized("...")` literal against
  `lily/Localizable.xcstrings`: one key per literal, every key used, every language present).
