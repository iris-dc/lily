# Shell

Source: `lily/Features/Shell/`

## Overview

The main shell around the signed-in and guest experience: the `TabView` of Home, Explore and Chats (behind
`AppConfig.FeatureFlags.chat`), the corner control and the profile sheet mount (the profile is no tab since
2026-11-07, the relocation contract), the Home root and its overview, the Explore and Chats tab wrappers, and the
app-lifetime services behind them. The feature has no direct source files. `Models` holds the tab list, the create
intent, the guest-or-overview rule and the segmented Home's pane list (`HomeSegment`, 2026-11-14); `Services` holds `ShellLists` (the Home and Explore list view models,
owned for the app's lifetime and cleared with the session), `ShellSync` (the ordered per-user sync chain run for every
scene phase and user) and `TabBadgeRenderer` (the Chats tab's unread count drawn into its glyph image, cached per
count and colour; 2026-11-12); `Views` draws the tabs and screens from `dependencies.lists` and `dependencies.navigation`. The
screens inside the tabs and the sheet (`ProfileView`, `ChatsView`, `ChatsSplitView`, `EventListView`,
`EventDetailView`, the carousels) belong to other features.

## Subdirectories & Boundaries

- Models: [./Models/EGM.md](./Models/EGM.md) - `AppTab` (`home`, `explore`, `chat`; `shown` drops `chat`
  with the flag off; `title`), `CreateIntent` (`game`, `group`, `tournament`), `HomeContent` (`signInPrompt` or
  `overview` from `SessionState.isSignedIn`), and `HomeSegment` (2026-11-14: `events`, `tournaments`, `groups`;
  `offered(groups:tournaments:)` under the feature flags with events always kept, plus each segment's copy, glyph
  and wizard seed — the whole-screen `HomeOverviewState` rule was deleted with the segmented redesign; a pane's
  state is the shared `ListState` in `lily/Core/Changes`). All `nonisolated`, pure.
- Services: [./Services/EGM.md](./Services/EGM.md) - `ShellLists: SessionObserver` (`homeEvents`, `homeTournaments`,
  `exploreEvents`, `discover`, `exploreTournaments`; `loadExploreIfStale()` runs the three position-first loads
  concurrently behind their flags; `sessionDidEnd()` clears all five) and `ShellSync` (`restore()` = session check then
  `push.openPendingTap()`; `run(active:user:)` = session check, account, realtime `setDesired`, groups, inbox, block
  list, push offer and sync, with Explore's loads alongside, a cancellation guard between every step and nothing loaded
  for a signed-out visitor or an inactive phase), and `TabBadgeRenderer` (the badged Chats glyph:
  `icon(symbol:count:glyphColor:badgeColor:)`, `nil` at zero, "99+" cap, one cached composite per count and colour;
  2026-11-12).
- Views: [./Views/EGM.md](./Views/EGM.md) - `MainTabView` (the `TabView` bound to `AppNavigation.selectedTab`, empty
  with the bar hidden while `!showsContent`, chat badge from `unreadCenter` and `inbox.hasUnread` drawn into the glyph image
  (`TabBadgeRenderer`, 2026-11-12: the system badge is immovable on the iOS 26 bar), outline glyphs via
  `UIImage.SymbolConfiguration`, `usesSplitChats` from `LayoutMode`; mounts the profile sheet above the per-tab
  language identity), `TabBarBareCircle` (the UIKit seam keeping the minimized circle's mirrored glyph plain, so the unread count fades with the menu), `ProfileCornerButton` (the shared `.topBarLeading` control at
  the four stack roots, initials or the person glyph, raising `AppNavigation.isProfilePresented`; 2026-11-07),
  `HomeTab` and `ChatTab` (the stacks bound to
  `homePath` and `chatPath`; the iPad split view for a signed-in regular width), `HomeView` (guest prompt or overview;
  loads after `sessionController.restore()` only for `.overview`, keyed on user id and change versions; hosts the
  create button's wizard through the shared `creationWizardPresenter` — a cover on compact, a form sheet otherwise;
  2026-11-14),
  `HomeOverview` (the segmented Events | Tournaments | Groups panes, one list at a time with a per-segment create
  button, count line, empty and failed states, and pull-to-refresh of the visible segment alone; 2026-11-14), `ExploreTab` (`EventListView` with the
  group and tournament carousels, reloading on `groupChanges` and `tournamentChanges`), `GuestSignInPrompt`.
