# Shell: Views

Source: `lily/Features/Shell/Views/`

## Overview

The signed-in and guest shell: a `TabView` of Home, Explore and Chats (flag-gated), kept by the root for the
app's lifetime and empty while the landing covers it; the profile as a sheet, presented once from the shell root over
the corner control every tab root carries (`ProfileCornerButton`; the Profile tab was removed 2026-11-07, the
relocation contract); the Home root with its guest prompt or the segmented overview (one of the caller's lists at a time behind the
Events | Tournaments | Groups picker, each segment with its own create button seeding the creation wizard; 2026-11-14);
the Explore tab wrapping the shared `EventListView` with the group and tournament carousels; and the Chats tab choosing
between a stack and the iPad split view. Lists are read from `dependencies.lists` (`ShellLists`), navigation from
`dependencies.navigation` (`AppNavigation`), and the screens shown inside (`ProfileView`, `ChatsView`, `ChatsSplitView`,
`EventListView`, `EventDetailView`, `GroupCarousel`, `TournamentCarousel`) belong to other features.

Files: `lily/Features/Shell/Views/MainTabView.swift`, `lily/Features/Shell/Views/TabBarBadgeOverlay.swift`,
`lily/Features/Shell/Views/TabBarCollapse.swift`, `lily/Features/Shell/Views/ProfileCornerButton.swift`,
`lily/Features/Shell/Views/HomeTab.swift`,
`lily/Features/Shell/Views/HomeView.swift`, `lily/Features/Shell/Views/HomeOverview.swift`,
`lily/Features/Shell/Views/ExploreTab.swift`, `lily/Features/Shell/Views/ChatTab.swift`,
`lily/Features/Shell/Views/GuestSignInPrompt.swift`.

## Interface

- `[MainTabView.swift:MainTabView]`: `dependencies: AppDependencies`, `showsContent: Bool`; reads `\.layoutMode`.
  `TabView(selection: $navigation.selectedTab)` of `Tab(value: .home)` (`HomeTab`), `.explore` (`ExploreTab`) and `.chat`
  (`ChatTab`, its label `chatTabLabel(count:selected:)`: the unread count drawn into the glyph image by the
  `@State`-held `TabBadgeRenderer`, because the bar ignores `UITabBarAppearance.badgePositionAdjustment` (2026-11-12
  probe) and honours only the label's title and `UIImage`; the composite is `.alwaysOriginal`, so the glyph colour
  follows `navigation.selectedTab` — `UIColor(Color.lilyAccent)` selected, `DesignTokens.TabBar.unselectedGlyphColor`
  otherwise — at zero the plain template `tabLabel` returns, and the count passed is zero while `TabBarBadgeOverlay`
  reports itself hosting (`overlayCarriesBadge`; the overlay mounts in the `TabView`'s background behind the chat
  flag on compact widths only — the iPad's top bar never minimizes and is no `UITabBar`, so regular widths keep the
  composite), so the bar holds the plain glyph while the overlay floats the fading capsule (2026-11-19), see
  `docs/notes/design-and-ui.md`); every tab's
  tree carries `.id(language)` where
  `language = dependencies.language.language`. The profile sheet mounts on the `TabView` (2026-11-07):
  `.sheet(isPresented: $navigation.isProfilePresented) { ProfileView(dependencies:language:) }` with
  `.presentationDragIndicator(.visible)` (2026-11-15: the grabber on every swipe-closable sheet) — above each tab's
  `.id(language)` (a language pick rebuilds the tabs while the sheet re-renders in place) and inside the root's
  `.id(shellGeneration)`. `unreadChats =
  dependencies.unreadCenter.count + (dependencies.inbox.hasUnread ? 1 : 0)`, exposed as
  `.accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)`. Labels pair
  `AppBranding.homeTitle`/`exploreTitle`/`chatsTitle` with `DesignTokens.Symbols.home`/`explore`/
  `chat` through `tabLabel(for:symbol:)`, which reads the title from `AppTab.title`, a `UIImage.SymbolConfiguration(weight:
  DesignTokens.TabBar.symbolWeight)`; `.tabBarMinimizeBehavior(.onScrollDown)`.
- `[TabBarCollapse.swift:TabBarCollapse]`: `Phase { expanded, minimized, morphing }`; `static func
  phase(visiblePaneWidths: [CGFloat], barWidth: CGFloat) -> Phase` — morphing iff a laid-out visible platter (at
  least `AppConfig.Shell.tabBarPlatterMinimumFraction` of the bar; the platter scales with the bar) and a circle
  (a pane at most the absolute `AppConfig.Shell.tabBarCircleMaxWidth`; the 48 pt circle and the ~100 pt tab-switch
  transient are absolute sizes on every device, and a width-relative quarter-bar bound read the transient as the
  circle on 400 pt-class bars, flickering the capsule on every tab switch there) show together, which is how a
  starting collapse or expand announces itself about 0.7 s before the leaving pane hides; one endpoint alone is
  its settled state and every other shape or fail-safe (no pane, no laid-out pane, a zero bar, a lone mid-size
  pane) answers expanded (a pre-layout read must never latch the capsule faded out; the midpoint itself reads as
  expanded). `static func settle(current: Phase, previous: Phase?) -> Phase` — the settled phase carried across
  reads: a settled read replaces it, a morph keeps it, and a mid-morph first read seeds minimized, so the capsule
  errs visible until the next settle. `static func fadesOut(phase: Phase, settled: Phase) -> Bool` — out while
  minimized, shown while expanded, mid-morph the opposite of the last settled state. (`isMinimized` was deleted:
  it had no production caller, `phase` is the one rule.)
- `[TabBarCollapse.swift:TabBadgePlacement]` (2026-11-19): the overlay's pure placement and trust rules.
  `capsuleCenter(glyphCenter:glyphSize:)` — the owner-tuned `DesignTokens.TabBar.badgeCenterOffset` from the
  top-right corner of the drawn glyph's box, anchored on the glyph view's centre (the bar centres the glyph in its
  item whichever image it holds, so the handoff from the composited label moves nothing).
  `chatsColumn(itemColumns:chatIndex:expectedTabs:)` — the platter's item views deduplicated into x-columns (it
  holds two parallel item trees at identical frames); only exactly one column per tab, in bar order, is trusted,
  anything else answers `nil` and the overlay stands down.
- `[TabBarBadgeOverlay.swift:TabBarBadgeOverlay]` (2026-11-19): `UIViewRepresentable` over `count: Int`, `renderer:
  TabBadgeRenderer`, `logger: any Logging` and `onHosting: (Bool) -> Void`; its `OverlayView` finds the `UITabBar`
  backing SwiftUI's `TabView` in its window (breadth-first walk, public class check; the bar joins the window a few
  frames after the overlay's view, so a failed find retries on `AppConfig.Shell.tabBarFindRetryDelay` deferrals, at
  most `tabBarFindAttempts` — a bounded search, never steady-state polling; a pane or item churn starts a fresh
  search with the whole budget again, and a search that spends it logs one `.ui` warning, "Tab badge overlay stood
  down"), resolves the Chats item's glyph
  image view inside the widest pane (`TabBadgePlacement.chatsColumn` over `AppTab.shown`), and keeps one capsule
  `UIImageView` (`TabBadgeRenderer.capsule`, accent) as a bar subview above the panes, centred by
  `TabBadgePlacement.capsuleCenter` over `TabBadgeRenderer.glyphSize` (re-fronted only when another subview sits
  above it: an unconditional bring-to-front churned the bar's sublayers on every KVO tick and fed the observation
  back to itself). KVO (`CALayer` is KVO-compliant where
  `UIView` is not): the panes' `isHidden`/`opacity` drive the capsule's alpha through the morph rule
  (`TabBarCollapse.phase` with `settle(current:previous:)` and `fadesOut(phase:settled:)` — the circle pane joins
  the platter on screen the moment
  a morph starts, so the fade runs over the collapse and the expand, not after them; a `UIView` fade,
  `DesignTokens.TabBar.badgeFadeDuration` and `badgeFadeOptions`), the glyph layer's
  `bounds`/`position`/`contents` re-position the capsule, and a `sublayers` churn re-attaches — only when the pane
  set itself changed, compared by identity, or the resolved glyph died with a re-created item. `onHosting` is
  reported deduplicated a turn later (`DispatchQueue.main.async` — KVO can fire inside a UIKit layout pass, and
  the handler writes SwiftUI state; the closure is read at delivery, so `updateUIView` replacing it never leaves a
  stale one, and a dismantled overlay's is nilled after the final hand-back); a stand-down removes the capsule one
  turn after the `false` delivery, so the count never blanks between the two carriers.
- `[ProfileCornerButton.swift:ProfileCornerButton]` (2026-11-07): `ToolbarContent` over `dependencies`; one
  `.topBarLeading` item under `.sharedBackgroundVisibility(.hidden)` whose button sets
  `navigation.isProfilePresented = true`. The label is an `AvatarCircle` at `DesignTokens.Layout.profileCornerSize`:
  the signed-in caller's initials from `dependencies.profile.displayName` (the snapshot answers at first frame; the
  button itself triggers no request), the `DesignTokens.Symbols.profile` glyph for a guest or while no name is known —
  the profile header's own fallback. Accessibility label `AppBranding.profileTitle`, identifier
  `AccessibilityIdentifiers.profileCorner`. Applied at exactly four stack roots, nowhere else: `HomeView`,
  `EventListView` (Explore's root), `ChatsView` and `ChatsSplitView`'s sidebar column (the relocation contract §3).
  The rendering was settled by the 2026-11-08 design round: the hidden capsule and the 36 pt circle kept as rendered
  (`docs/notes/design-and-ui.md` 2026-11-08; shots under
  `reviews/2026-11-07-profile-lifecycle-brainstorm/slice4-shots/design-round/`). An owner correction the same day
  backs the circle out of the hidden capsule's 10 pt content inset (`.padding(.leading,
  -DesignTokens.Layout.profileCornerCapsuleInset)`), so it takes the capsule's own leading edge — flush with the
  large titles' 16 pt margin on the iPhone, the system capsule's own edge on the iPad (`design-and-ui.md` 2026-11-08,
  owner corrections; shots under `reviews/2026-11-07-profile-lifecycle-brainstorm/corrections1-shots/`).
- `[HomeTab.swift:HomeTab]`: `NavigationStack(path: $navigation.homePath) { HomeView(dependencies:) }` with
  `.animatesTabBar(depth: navigation.homePath.count)`.
- `[HomeView.swift:HomeView]`: `dependencies`; `events = dependencies.lists.homeEvents`, `tournaments =
  dependencies.lists.homeTournaments`; `content = HomeContent(for: dependencies.sessionController.state)`; a private
  `LoadKey: Hashable { userID: String?; eventsVersion: Int; tournamentsVersion: Int }`; `@State wizardModel:
  AppCreationWizardModel?` and `@State presentedSheet: WizardOnlySheet?` (2026-11-14: the create button's wizard,
  made once per presentation in `presentCreate(_:)` and owned above both presenters, so a mid-flow width-class
  change re-hosts the same flow instead of destroying it). Body: `ContentScreen` showing
  `GuestSignInPrompt(symbolName: DesignTokens.Symbols.home, message: AppBranding.Home.guestMessage, dependencies:)` or
  `HomeOverview(groups: dependencies.myGroups, events:, tournaments:, dependencies:, onCreate: presentCreate)`;
  `.navigationTitle(AppBranding.homeTitle)`;
  `.toolbar { ProfileCornerButton(dependencies:) }`;
  `.groupDestinations(dependencies:onTournamentChange: tournaments.replace)`; `.navigationDestination(for:
  SportEvent.self)` pushing `EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for:onChange:
  events.replace), dependencies:)`; `.creationWizardPresenter(item: $presentedSheet, model: wizardModel,
  errorCenter:, onDismissed: wizardDismissed)` — the shared host
  ([`../../Create/Views/EGM.md`](../../Create/Views/EGM.md)): a full-screen cover on a compact width, a
  `lilyFormSheet()` sheet otherwise, exactly as Explore presents the wizard; `.task(id: loadKey) { await
  loadIfStale() }`. `presentCreate(_ kind: CreationKind)` builds the model through
  `dependencies.makeCreationWizardModel(seed: CreationSeed(kind:), onCreatedEvent:onCreatedGroup:onCreatedTournament:)`
  and sets `presentedSheet = .wizard`; `wizardDismissed()` books the flow's close (`wizardModel?.noteClosed()`, once
  and never after a create) and drops the model.
- `[HomeOverview.swift:HomeOverview]` (segmented 2026-11-14, the owner's variant-C choice): `groups: MyGroupsStore`,
  `events: EventListViewModel`, `tournaments: TournamentListViewModel`, `dependencies`, `onCreate: (CreationKind) ->
  Void`; `@State segment: HomeSegment = .events`; reads `\.horizontalSizeClass` and `\.motion`. Renders a refreshable
  scroll of: the segmented `Picker` over `HomeSegment.offered()` (label `AppBranding.Home.segmentPicker`, identifier
  `AccessibilityIdentifiers.homeSegment`, `.readableColumn()`); the full-width create button (`segment.createTitle`
  under `lilyGlassButton(labelColor: .lilyInk)` with the accent on the `DesignTokens.Symbols.create` glyph alone,
  identifier `AccessibilityIdentifiers.homeCreate`) calling `onCreate(segment.creationKind)`; and `segmentContent` —
  one `slot(state:count:content:)` per segment over `events.listState` / `events.visibleEvents`,
  `tournaments.listState` / `tournaments.visibleTournaments` or `groups.listState` / `groups.communities`,
  drawing `EventCardList(events:distance:)`, `TournamentCardList(tournaments:distance:)` or `groupsList`. A
  `.content` slot puts the `.footnote` `.secondary` count line (`segment.countLine(_:)`) over the list; `.loading` a
  `ProgressView`; `.failed` the quiet `segment.failedMessage` note; `.empty` an `EmptyStateView(symbolName:
  segment.symbolName, title: segment.emptyTitle, message: segment.emptyMessage)` — the copy all carried by
  `HomeSegment` ([`../Models/EGM.md`](../Models/EGM.md)). The segment switch animates
  `.snappy(DesignTokens.Duration.fast)` only while `motion.allowsMovement`.
- `[ExploreTab.swift:ExploreTab]`: `dependencies`; `discover = dependencies.lists.discover`, `tournaments =
  dependencies.lists.exploreTournaments`; body is `EventListView(listTitle:, viewModel: dependencies.lists.exploreEvents,
  dependencies:, refreshHeader: refreshCarousels, header: carousels)` with `listTitle = AppBranding.Events.eventsSection`
  when a carousel shows, else `nil`; `carousels()` is `GroupCarousel(viewModel: discover)` and
  `TournamentCarousel(viewModel: tournaments)` behind their flags.
- `[ChatTab.swift:ChatTab]`: `dependencies`; reads `\.layoutMode`; `ChatsSplitView(dependencies:)` when
  `showsSplitView`, else `NavigationStack(path: $navigation.chatPath) { ChatsView(dependencies:) }` with
  `.animatesTabBar(depth: navigation.chatPath.count)`.
- `[GuestSignInPrompt.swift:GuestSignInPrompt]`: `symbolName: String`, `message: String`, `dependencies`; `@State
  isSignInPresented`; `EmptyStateView(symbolName:, title: AppBranding.guestProfileTitle, message:, actionTitle:
  AppBranding.signInAction)` under `.readableColumn()`, presenting `SignInSheet(session:errorCenter:)`.

## Invariants

- `[MainTabView.swift:MainTabView.body]`: the Chats tab exists only `if AppConfig.FeatureFlags.chat`; while
  `!showsContent` every tab's content is `Color.clear.toolbarVisibility(.hidden, for: .tabBar)`, so no screen loads or
  asks for the position behind the landing and the bar stays built but hidden; `.animation(nil, value: showsContent)`
  keeps the bar from sliding in.
- `[MainTabView.swift:MainTabView.body]`: `.onChange(of: layoutMode.isRegular, initial: true)` writes
  `dependencies.navigation.usesSplitChats`; the navigation model never reads size classes itself.
- `[MainTabView.swift:MainTabView.body]`: the terms-over-sheet yield was removed 2026-11-08 with the terms gate
  (owner decision: the app never prompts to accept terms); the profile sheet is the shell's root-level sheet. A
  session end tears it down twice over: `sessionDidEnd()` clears the flag and the `shellGeneration` bump rebuilds the
  view.
- `[TabBarBadgeOverlay.swift:TabBarBadgeOverlay]` (2026-11-19): the fade runs over the morph, not after it — both
  endpoints visible at once is the morphing phase, faded toward the opposite of the last settled state, so an
  abandoned morph corrects itself at the next settle; the settled state is seeded from the first read (a first
  read that lands mid-morph seeds minimized, so the capsule errs visible until the next settle); a pane before its
  first layout reports zero width and is no
  signal, and every fail-safe answers expanded (a pre-layout read can never latch the capsule faded out). The fail-safe direction: whenever the hierarchy is
  missing or not the expected shape (no `UITabBar`, the find budget runs out — replenished by the next churn, the
  exhaustion logged at warning —, `TabBadgePlacement.chatsColumn`
  distrusts the item columns, a re-created item loses the glyph), `onHosting` reports `false` and `MainTabView`
  composites the count into the glyph as before — an unread count is never lost, and never blank: the capsule
  leaves only after the `false` delivery has had a body-pass turn, so a handoff may double-draw briefly but never
  shows nothing; the recorded cost is the old
  capsule-past-the-rim overflow returning silently (and a signal lost after hosting leaves the overlay showing at
  its last anchor). The capsule is a subview of the bar itself, so the bar's own hiding, alpha and removal carry it,
  and no pane's clip can cut it. The first state application snaps with no animation; a re-attach with an unchanged
  state leaves a running fade alone. Regular widths never mount the overlay (the iPad's top bar never minimizes and
  is no `UITabBar`); the 17 Pro's Chats list never crosses the minimize threshold, so only a compact phone that
  collapses the bar ever fades the capsule.
- `[HomeView.swift:HomeView.loadIfStale]`: `await dependencies.sessionController.restore()` first, then `guard
  !Task.isCancelled, content == .overview else { return }`: a guest asks for nothing and nothing is requested before the
  pool confirmed the cached user. The three loads (`events.loadIfStale()`, `myGroups.loadIfStale()` behind
  `AppConfig.FeatureFlags.groups`, `tournaments.loadIfStale()` behind `AppConfig.FeatureFlags.tournaments`) run as
  `async let` children; the position is asked for after them. The `.task(id: loadKey)` restarts on a new user id or a
  bump of `dependencies.eventChanges.version` / `dependencies.tournamentChanges.version`. All three lists load
  although one segment shows (deliberate, 2026-11-14: a segment switch answers from memory at once).
- `[HomeOverview.swift:HomeOverview.body]` (2026-11-14): the picker offers only `HomeSegment.offered()`, so a feature
  flag that is off removes its segment (events always ship); every segment keeps the create button, the empty and
  failed states included.
- `[HomeOverview.swift:HomeOverview.segmentContent]`: the per-segment pane state is the shared `ListState` rule
  (`lily/Core/Changes/ListState.swift:ListState`) — every pane reads its owner's own `listState` resolver
  (`events.listState`, `tournaments.listState`, `groups.listState`; the store's fold is contracted in
  [`../../Groups/State/EGM.md`](../../Groups/State/EGM.md)); nothing here re-implements or re-derives the rule.
- `[HomeOverview.swift:HomeOverview.groupsList]`: `sizeClass == .regular` draws the tile grid, any other width the
  row list.
- `[ExploreTab.swift:ExploreTab.showsGroups]`: `AppConfig.FeatureFlags.groups && !discover.groups.isEmpty`;
  `showsTournaments` likewise with `tournaments.visibleTournaments`.
- `[ChatTab.swift:ChatTab.showsSplitView]`: `layoutMode.isRegular && HomeContent(for:
  dependencies.sessionController.state) == .overview`; a guest gets the full-width stack on every width.
- `[HomeView.swift:HomeView.body]`: the one `SportEvent` navigation destination on the Home stack is declared here.

## Side Effects

- Loads: `[HomeView.swift:HomeView.loadIfStale]` calls `sessionController.restore()`, `events.loadIfStale()`,
  `myGroups.loadIfStale()`, `tournaments.loadIfStale()`, then `events.loadUserLocation()` and (flag)
  `tournaments.loadUserLocation()` (location permission and fix). `[ExploreTab.swift:ExploreTab.body]` runs
  `.task(id: dependencies.groupChanges.version)` → `discover.loadIfStaleNearTheUser()` and `.task(id:
  dependencies.tournamentChanges.version)` → `tournaments.loadIfStaleNearTheUser()`; `refreshCarousels` calls
  `discover.search()` and `tournaments.load()`.
- `[HomeOverview.swift:HomeOverview.refreshVisible]`: pull-to-refresh reloads the visible segment alone —
  `events.load()`, `tournaments.load()` or `groups.reload()` (2026-11-14; all three until then).
- Navigation writes: `[HomeOverview.swift:HomeOverview.groupsList]` `dependencies.navigation.open(group:)` (the
  whole-screen empty state and its Explore jump were removed 2026-11-14 with the segmented redesign);
  `[MainTabView.swift:MainTabView.body]` binds `selectedTab` and `isProfilePresented` (presenting `ProfileView` as the
  profile sheet, which mounts its own `.errorPopup`), sets `usesSplitChats`; `[ProfileCornerButton.swift:ProfileCornerButton]` sets `isProfilePresented = true`;
  `[HomeTab.swift:HomeTab]` and `[ChatTab.swift:ChatTab]` bind `homePath` and `chatPath`.
- `[MainTabView.swift:MainTabView.tabLabel(for:symbol:)]`: builds `UIImage(systemName:withConfiguration:)` glyphs (UIKit); `chatTabLabel(count:selected:)` asks the `@State` `TabBadgeRenderer` for the badged composite, rendered once per count and colour and cached (2026-11-12).
- `[TabBarBadgeOverlay.swift:TabBarBadgeOverlay.OverlayView]`: adds one capsule `UIImageView` to the found bar and
  installs KVO observations on the bar's pane layers, their sublayers and the Chats glyph's layer (replaced only
  when the observed pane set changed or the glyph died; released with the view, the capsule removed on teardown);
  animates the capsule's alpha; logs one warning (`.ui`) when a find budget is spent; no polling once the bar is
  found, no network, disk or `UserDefaults` access.
- `[GuestSignInPrompt.swift:GuestSignInPrompt]`: presents `SignInSheet`, which mounts its own `.errorPopup`.
- `[HomeView.swift:HomeView.body]`: `tournaments.replace` and `events.replace` are handed to the destinations as change
  callbacks that mutate the Home lists.
- `[HomeView.swift:HomeView.presentCreate]` (2026-11-14): builds the wizard model — `onCreatedEvent` runs
  `events.add` then `navigation.open(event:)`, `onCreatedGroup` `navigation.open(group:)`, `onCreatedTournament`
  `tournaments.add` (inserted, not refetched: the by-user index is eventually consistent and could answer without
  the new tournament; `add` still invalidates the sibling lists) then `navigation.open(tournament:)` — and
  `[HomeView.swift:HomeView.wizardDismissed]` books `noteClosed()` on a real dismissal alone, never on a re-host.
- Beyond the overlay's stand-down warning, no logging is made directly by these views, and no disk or `UserDefaults` access.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the segment model these views draw is pinned in
  `lilyTests/Shell/HomeSegmentTests.swift`, the collapse phase, settle and fade rules (pinned at bar widths 375, 402 and 440) in `lilyTests/Shell/TabBarCollapseTests.swift`, the
  overlay's placement and trust rules in `lilyTests/Shell/TabBadgePlacementTests.swift` and
  the pane rule in `lilyTests/Changes/ListStateTests.swift`; the screens
  themselves are exercised by the UI tests, `./scripts/ci.sh ui` and `./scripts/ci.sh ui-ipad`; the capsule's fade
  is UIKit runtime behaviour, proven on film — `docs/notes/design-and-ui.md` 2026-11-19).
