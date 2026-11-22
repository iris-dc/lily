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
`lily/Features/Shell/Views/TabBarBadgeOverlay+Resolve.swift`, `lily/Features/Shell/Views/TabBarBadgeOverlay+Churn.swift`, `lily/Features/Shell/Views/TabBadgePlacement.swift`, `lily/Features/Shell/Views/ProfileCornerButton.swift`,
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
  composite), so the bar holds the plain glyph while the overlay rides the capsules inside the Chats items (2026-11-19/20), see
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
- `[TabBadgePlacement.swift:TabBadgePlacement]`: the overlay's pure placement and trust rules.
  `capsuleCenter(glyphCenter:glyphSize:)` — the owner-tuned `DesignTokens.TabBar.badgeCenterOffset` from the
  top-right corner of the drawn glyph's box, anchored on the glyph view's centre in whatever space the caller
  measured it (the overlay feeds each glyph's centre in its item's own coordinates; the bar centres the glyph in its item whichever
  image it holds, so the handoff from the composited label moves nothing).
  `chatsColumn(itemColumns:chatIndex:expectedTabs:)` — the platter's item views deduplicated into x-columns (it
  holds two parallel item trees at identical frames); only exactly one column per tab, in bar order, is trusted,
  anything else answers `nil` and the overlay stands down.
  `treeCount(itemColumns:expectedTabs:)` — every column must carry the same number of controls (the trees are
  identical copies) or nothing is trusted: whole trees only, since a partial tree would pin the count to
  whichever copy happened to resolve.
  `isPlatter(paneWidth:barWidth:)` — only a pane spanning at least `AppConfig.Shell.tabBarPlatterMinimumFraction`
  of a laid-out bar is the expanded platter: the minimized circle (48 pt), the ~100 pt tab-switch transient and a
  pre-layout zero-width pane never host the capsule.
  `handoffStep(isHosting:graceArmed:deadline:now:)` and `armedGraceDeadline(isHosting:graceArmed:now:)` — the
  hand-off grace decisions, pure over the caller's clock (2026-11-22): only a hosted churn arms the grace, once
  per episode (never extended); inside the deadline a hosted failure retries (`.graceRetry`), past it — or once
  hosting already ended — an armed failure hands off saying so (`.handOffAfterGrace`), an unarmed one at once
  (`.handOff`); the grace must outlast `tabBarFindRetryDelay`, pinned, or the retries would be theatre.
  `hostsAreStale(current:resolved:hostCount:)` — resolved hosts must match the drawn trees' glyphs by count AND
  identity; an empty current shape is mid-churn noise, not staleness. (`TabBarCollapse` — the phase, settle and fade
  detector — was deleted 2026-11-19 with the hand-run fade: the capsules ride inside the Chats items and the
  bar's own treatments carry their motion and visibility, leaving nothing to time.)
- `[TabBarBadgeOverlay.swift:TabBarBadgeOverlay]` (2026-11-19): `UIViewRepresentable` over `count: Int`, `renderer:
  TabBadgeRenderer`, `logger: any Logging` and `onHosting: (Bool) -> Void`; its `OverlayView` finds the `UITabBar`
  backing SwiftUI's `TabView` in its window (breadth-first walk, public class check; the bar joins the window a few
  frames after the overlay's view, so a failed find retries on `AppConfig.Shell.tabBarFindRetryDelay` deferrals, at
  most `tabBarFindAttempts` — a bounded search, never steady-state polling; a pane or item churn starts a fresh
  search with the whole budget again, and a search that spends it logs one `.ui` warning, "Tab badge overlay stood
  down"), resolves the Chats items' glyph image views inside the expanded platter — the widest pane passing
  `TabBadgePlacement.isPlatter`, the Chats column by `TabBadgePlacement.chatsColumn` over `AppTab.shown`, one item
  per parallel tree — and keeps one capsule `UIImageView` per item (`BadgeHost`; `TabBadgeRenderer.capsule`,
  accent, pixel-identical twins of one render) as a subview of each item directly above its glyph image view,
  centred by `TabBadgePlacement.capsuleCenter` over `TabBadgeRenderer.glyphSize` in the item's own coordinates.
  Inside the item, every treatment the glyph gets carries the capsule with it, with no animation code of ours: the
  platter's collapse morph (a presentation-level animation that never touches model geometry), a selection
  crossfade between the trees, and the selection lens — which, a second device recording and the hierarchy probe
  showed (2026-11-20, `item2-badge-ride-fix2/fix8-initem/probe.log`), draws a magnified copy of the selected
  item's own subtree through a `_UIPortalView` above its glass, so a platter-sibling capsule stayed dimmed in the
  backdrop beneath the lens while the glyph's copy drew crisp over it — no layer z-position can beat a portal that
  does not sample it, so `badgeZPosition` was deleted with that mount, and only in-item content is copied with the
  icon. Two capsules because the platter draws two full item trees at identical frames (`SelectedContentView` and
  `ContentView`, both fully opaque in every settled state, a `DestOutView` punching the backdrop out under the
  lens) and which tree the lens samples or a transition fades is not observable: the glyphs are drawn once per
  tree, so a capsule per tree is exactly-like-the-icons by construction. A phone recording also showed the
  device's bar never flips its panes' hidden flags — the pill morphs into the minimized circle as one continuous
  animation — so only in-pane content inherits the bar's animations on every hierarchy; the minimized circle pane
  is its own platter and never hosts, so the bare circle stays bare; the bar-level twin with its pane-state rule
  was deleted the same day (the find and retry half stays split in `TabBarBadgeOverlay+Resolve.swift` under the
  file length limit). The platter clips to its bounds, so a capsule the clip would cut (each capsule's frame
  converted into the platter, the ancestor that clips, at every reposition — on model geometry, which the morph
  never moves) stands down to the composite behind the `capsuleUnfit` flag with the glyphs and observations kept,
  so the same layout moving back re-mounts without a search (nil'ing the glyph churned our own subview into a
  fresh attach whose budget replenish made the loop unbounded). Debug builds record every attach, churn, host
  flip, fit trip and eviction plus a 2 s bar-and-window-shape tail through
  `BadgePaneDiagnostics.shared` — a deliberate debug-only exception to the no-concrete-types rule: a `#if DEBUG`
  tool, and an injected seam would put debug plumbing into `updateUIView` for every build. `diagnose(_:)` takes an
  `@autoclosure`, so release builds evaluate nothing, and its DEBUG body mirrors each event through
  `logger?.debug(.ui, ...)` for an attached console and `SpyLogger`. KVO (`CALayer` is
  KVO-compliant where `UIView` is not): each glyph layer's `bounds`/`position` re-position its capsule when layout
  really moves it, and a `sublayers` churn on the bar or a pane re-attaches — only when the platter itself left
  the bar, a resolved host died — deadness includes a glyph left windowed but HIDDEN below the pane (`isDrawable`, the re-stack's other face: the capsule census read mounted, visible-state and layer-rooted while the screen showed no badge) — or the drawn trees' glyphs no longer match the resolved ones by identity
  (`hostsAreStale`: the select re-stacks the platter's content one level below the observed pane layers about a
  second after it settles, leaving mounts windowed in a stale, undrawn subtree while every observed layer stays
  quiet — the transient pane still joins and leaves on every tab switch, so plain pane-set comparisons would
  churn hot; the count-and-identity rule is the pinned pure `TabBadgePlacement.hostsAreStale`) — or the stored
  platter stopped being the qualifying widest pane, or hides while another qualifying pane stands (a pane-level
  replacement the glyph rules are blind to, re-judged on every pane churn; a plain minimize hides the platter
  with no other qualifying pane and never trips it). Adoption uses the condemnation standard too (2026-11-22):
  `chatsGlyphs` filters controls and glyphs failing `isDrawable` (its alpha floor the named
  `AppConfig.Shell.tabBarDrawableAlphaMinimum`), so a stale hidden tree beside the live ones is simply ignored
  and a shape where only stale trees parse as whole FAILS the resolve onto the grace path — never an
  adopt-and-condemn spin; each capsule also reports
  its own eviction (`didMoveToWindow`), because a re-created item dies with its subviews and no observed layer
  announces that — a deferred re-check at delivery keeps a deliberate teardown or stand-down from re-attaching.
  `onHosting` is reported deduplicated a turn later (`DispatchQueue.main.async` — KVO can fire inside a UIKit
  layout pass, and the handler writes SwiftUI state; the closure is read at delivery, so `updateUIView` replacing
  it never leaves a stale one, and a dismantled overlay's is nilled after the final hand-back); a stand-down or
  failed resolve retires the mounted capsules to a leaving list swept in the completion of the transaction whose
  commit carries the composite's body pass — or by the next successful mount, which replaces the old capsules only
  after the new ones are mounted — so the count never blanks between the two carriers, outside two deliberate
  windows: a grace retry strips its capsules at once (the badge absent inside an item that is itself
  mid-rebuild), and a fresh mount's fit trip unmounts at once rather than commit shaved; an evicted or dead host re-resolves and remounts in place
  in the deferred delivery turn — `host(true)` a no-op, `isHosting` never flipping, the label never swapped — and
  a failure right after any hosted churn retries until `AppConfig.Shell.tabBarHandoffGraceSeconds` (a deadline armed once per episode: the rebuild's own churns re-attach faster than the retry timer, so a counted grace would burn in a millisecond and a storm must not extend it either) before the hand-off: the
  device rebuilds the selected item non-atomically, so the re-resolve can meet half-built trees, and a composite
  hand-off would visibly crossfade through the rebuilding item (2026-11-22; the suspected cause of the owner's
  dim badge over the white glyph after an expand — not yet proven on the device: at the previous head the
  success-path flip was never delivered, so only this failure branch could swap the label, and the pulled
  diagnostics log is the verdict). A grace whose find budget runs out hands off right there (`scheduleRetry`'s
  spent path, 2026-11-22: the grace relies on a future retry for its hand-off, and a wedged hosting-true with no
  capsules and no timer must not exist; the stood-down warning stays for a silently lost bar). A fresh mount
  whose first fit judgment trips also hands off, its capsules leaving the screen synchronously — never a shaved
  commit; `freshMount` is consumed only by a COMPLETED fit-judgment pass — a liveness bail leaves it set and
  books a reposition, so un-centred capsules never persist and a later first judgment still takes the
  never-shaved path. A teardown hands back on the last DELIVERED hosting value, not on `isHosting` (a pending
  flip may have reset the flag while the composite still believes the overlay carries the count — the iPad
  compact-to-regular unmount), so a stranded `true` can never blank the count for the session.
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
- `[TabBarBadgeOverlay.swift:TabBarBadgeOverlay]` (2026-11-19/20): each capsule is a subview of its item tree's
  Chats item, directly above that tree's glyph, so everything the glyph gets — the platter's collapse morph, a
  selection crossfade, the lens's magnified copy — carries the capsule in lockstep by construction, with no fade
  or timing code in the app (the `TabBarCollapse` detector and the fade knobs were deleted with their one caller;
  the bar-level twin and its pane-state rule 2026-11-20, a phone recording showing the device's bar never flips
  pane hidden flags; `badgeZPosition` the same day, a second recording showing the lens copies only the item's own
  subtree); the minimized circle pane never hosts, so the bare circle never shows a count; the capsules hide only
  at a count of zero. The fail-safe direction:
  whenever the hierarchy is missing or not the expected shape (no `UITabBar`, the find budget runs out —
  replenished by the next churn, the exhaustion logged at warning —, `TabBadgePlacement.chatsColumn` or `treeCount` distrusts the
  item columns (whole trees only) past any armed grace — a grace whose find budget runs out hands off right
  there, never a wedge; a re-created item that loses a glyph or evicts a capsule
  re-resolves in place first), `onHosting` reports `false` and
  `MainTabView` composites the count into the glyph as before — an unread count is never lost, and never blank
  outside the two deliberate windows (a grace retry, a fresh mount's fit trip):
  failing paths retire the mounted capsules to a leaving list swept by the composite's commit, a successful
  re-resolve replaces them only after the new capsules are mounted, and an evicted or dead host re-resolves and
  remounts in place, handing off only when the fresh resolve still fails after the bounded grace, or at once when
  a fresh mount's first fit judgment trips (those capsules leave the screen synchronously — never a shaved
  commit) — a handoff may double-draw briefly but never shows nothing; the recorded costs are the old capsule-past-the-rim overflow returning silently
  (and a signal lost after hosting leaving the overlay showing at its last anchor). The capsules intercept no
  touches and are no accessibility elements (the tab's value stays the one VoiceOver seam). Regular widths never
  mount the overlay (the iPad's top bar never minimizes and is no `UITabBar`); the 17 Pro's Chats list never
  crosses the minimize threshold, so only a compact phone that collapses the bar ever rides the capsules through
  a morph.
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
- `[TabBarBadgeOverlay.swift:TabBarBadgeOverlay.OverlayView]`: adds one capsule `UIImageView` to each of the found bar's
  expanded platter pane's two Chats items (one per item tree, each directly above that tree's glyph) and installs
  KVO observations on the bar's layer, the panes' sublayers and each Chats
  glyph's layer (re-attached only when the platter left the bar, a resolved host died or the resolved glyphs went stale by identity; released with the
  view, the capsules removed on teardown); logs one warning (`.ui`) when a find budget is spent; animates nothing
  itself; no polling once the bar is found, no network, disk or `UserDefaults` access.
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
  `lilyTests/Shell/HomeSegmentTests.swift`, the
  overlay's placement and trust rules in `lilyTests/Shell/TabBadgePlacementTests.swift` and
  the pane rule in `lilyTests/Changes/ListStateTests.swift`; the screens
  themselves are exercised by the UI tests, `./scripts/ci.sh ui` and `./scripts/ci.sh ui-ipad`; the capsules' ride —
  motion, fade and the lens copy carried by the item's own treatment — is UIKit runtime behaviour, proven on film —
  `docs/notes/design-and-ui.md` 2026-11-19 and 2026-11-20).
