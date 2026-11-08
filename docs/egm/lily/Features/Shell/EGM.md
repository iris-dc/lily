# Shell

Source: `lily/Features/Shell/`

## Overview

The main shell around the signed-in and guest experience: the `TabView` of Home, Explore and Chats (behind
`AppConfig.FeatureFlags.chat`), the corner control and the profile sheet mount (the profile is no tab since
2026-11-07, the relocation contract), the Home root and its overview, the Explore and Chats tab wrappers, and the
two app-lifetime services behind them. The feature has no direct source files. `Models` holds the tab list, the create
intent and the pure state rules Home draws from; `Services` holds `ShellLists` (the Home and Explore list view models,
owned for the app's lifetime and cleared with the session) and `ShellSync` (the ordered per-user sync chain run for every
scene phase and user); `Views` draws the tabs and screens from `dependencies.lists` and `dependencies.navigation`. The
screens inside the tabs and the sheet (`ProfileView`, `ChatsView`, `ChatsSplitView`, `EventListView`,
`EventDetailView`, the carousels) belong to other features.

## Subdirectories & Boundaries

- Models: [./Models/EGM.md](./Models/EGM.md) - `AppTab` (`home`, `explore`, `chat`; `shown` drops `chat`
  with the flag off; `title`), `CreateIntent` (`game`, `group`, `tournament`), `HomeContent` (`signInPrompt` or
  `overview` from `SessionState.isSignedIn`), and `HomeOverviewState.resolve(events:groups:tournaments:)` over
  `HomeListSnapshot`s, yielding `loading`, `empty(loadFailed:)` or per-section `HomeSectionState`s with a `nil` list
  ignored. All `nonisolated`, pure.
- Services: [./Services/EGM.md](./Services/EGM.md) - `ShellLists: SessionObserver` (`homeEvents`, `homeTournaments`,
  `exploreEvents`, `discover`, `exploreTournaments`; `loadExploreIfStale()` runs the three position-first loads
  concurrently behind their flags; `sessionDidEnd()` clears all five) and `ShellSync` (`restore()` = session check then
  `push.openPendingTap()`; `run(active:user:)` = session check, account, realtime `setDesired`, groups, inbox, block
  list, push offer and sync, with Explore's loads alongside, a cancellation guard between every step and nothing loaded
  for a signed-out visitor or an inactive phase).
- Views: [./Views/EGM.md](./Views/EGM.md) - `MainTabView` (the `TabView` bound to `AppNavigation.selectedTab`, empty
  with the bar hidden while `!showsContent`, chat badge from `unreadCenter` and `inbox.hasUnread`, outline glyphs via
  `UIImage.SymbolConfiguration`, `usesSplitChats` from `LayoutMode`; mounts the profile sheet above the per-tab
  language identity and yields it to the terms sheet), `ProfileCornerButton` (the shared `.topBarLeading` control at
  the four stack roots, initials or the person glyph, raising `AppNavigation.isProfilePresented`; 2026-11-07),
  `HomeTab` and `ChatTab` (the stacks bound to
  `homePath` and `chatPath`; the iPad split view for a signed-in regular width), `HomeView` (guest prompt or overview;
  loads after `sessionController.restore()` only for `.overview`, keyed on user id and change versions),
  `HomeOverview` (sections, notes, empty and failed states, pull-to-refresh), `ExploreTab` (`EventListView` with the
  group and tournament carousels, reloading on `groupChanges` and `tournamentChanges`), `GuestSignInPrompt`.
