# Shell: Models

Source: `lily/Features/Shell/Models/`

## Overview

The shell's plain data: the tab list, the create intent a keyboard shortcut parks on the navigation model, what Home and
Chats show for a session state, and the segmented Home's pane list (`HomeSegment`, 2026-11-14 — the whole-screen
`HomeOverviewState` rule was deleted with the segmented redesign; a pane's state is the shared `ListState`,
`lily/Core/Changes/ListState.swift:ListState`, which the two list view models and `MyGroupsStore.listState` all feed).
All types are `nonisolated`, `Equatable`/`Hashable` and `Sendable`; the screen reads these instead of a store's flags.

Files: `lily/Features/Shell/Models/AppTab.swift`, `lily/Features/Shell/Models/CreateIntent.swift`,
`lily/Features/Shell/Models/HomeContent.swift`, `lily/Features/Shell/Models/HomeSegment.swift`.

## Interface

- `[AppTab.swift:AppTab]`: `nonisolated enum AppTab: Hashable, CaseIterable, Sendable` with cases `home`, `explore`,
  `chat` in bar order (the profile is no tab since 2026-11-07: the corner button presents it as a sheet,
  `AppNavigation.isProfilePresented`); `static var shown: [AppTab]` = `allCases.filter { $0 != .chat ||
  AppConfig.FeatureFlags.chat }`; `var title: String` maps to `AppBranding.homeTitle`, `.exploreTitle`, `.chatsTitle`.
- `[CreateIntent.swift:CreateIntent]`: `nonisolated enum CreateIntent: Hashable, Sendable` with cases `game`, `group`,
  `tournament`; a marker with no members.
- `[HomeContent.swift:HomeContent]`: `nonisolated enum HomeContent: Equatable, Sendable` with cases `signInPrompt`,
  `overview`; `init(for state: SessionState)` sets `self = state.isSignedIn ? .overview : .signInPrompt`.
- `[HomeSegment.swift:HomeSegment]` (2026-11-14): `nonisolated enum HomeSegment: CaseIterable, Hashable, Sendable`
  with cases `events`, `tournaments`, `groups` in the picker's order; `static func offered(groups: Bool =
  AppConfig.FeatureFlags.groups, tournaments: Bool = AppConfig.FeatureFlags.tournaments) -> [HomeSegment]` filters
  `allCases` by the flags, events always kept; per segment `title`, `createTitle` (the create button's words),
  `creationKind: CreationKind` (what the button seeds the wizard with), `symbolName` (the empty hint's glyph, from
  `DesignTokens.Symbols`), `emptyTitle`, `emptyMessage`, `failedMessage` and `countLine(_ count: Int)` (the
  catalog's `%lld` plural keys), all mapping to `AppBranding.Home` — most in
  `lily/Config/AppBranding+HomeSegments.swift`, while the root `lily/Config/AppBranding.swift` keeps `noGames`
  (`.events`' `emptyMessage`) and `gamesLoadFailed` / `groupsLoadFailed` (`.events`' and `.groups`' `failedMessage`),
  the split the Config contract records — plus `AppBranding.Tournaments.mineLoadFailed`
  (`lily/Config/AppBranding+Tournaments.swift`, `.tournaments`' `failedMessage`).

## Invariants

- `[AppTab.swift:AppTab.shown]`: keeps `allCases` order and drops `.chat` only when `AppConfig.FeatureFlags.chat` is
  off; the file's comment ties the ⌘1–⌘3 shortcuts to this list so the numbers never skip (`ShellCommands` numbers by
  `index + 1`, so Release, with chat off, is ⌘1 Home, ⌘2 Explore).
- `[HomeContent.swift:HomeContent.init]`: only `SessionState.isSignedIn` yields `.overview`; a guest or a signed-out
  state yields `.signInPrompt`.
- `[HomeSegment.swift:HomeSegment.offered]`: keeps `allCases` order, drops `.tournaments` and `.groups` only when
  their flag is off, and always contains `.events`, so the offer is never empty; the parameters default to the
  build's `AppConfig.FeatureFlags` and are injected only by tests.
- `[HomeSegment.swift:HomeSegment]`: every case carries its own copy — no two segments share a `title`, `createTitle`
  or hint — so the picker, the create button and the empty and failed states always name the visible segment.
- `[AppTab.swift:AppTab]`, `[CreateIntent.swift:CreateIntent]`, `[HomeContent.swift:HomeContent]`,
  `[HomeSegment.swift:HomeSegment]`: `nonisolated` value types, so they are `Sendable` and testable off the
  main actor.

## Side Effects

- None beyond reads: `[HomeContent.swift:HomeContent.init]` is a pure function of its input;
  `[AppTab.swift:AppTab.shown]` and `[HomeSegment.swift:HomeSegment.offered]` only read compile-time feature flags;
  `HomeSegment`'s copy members perform catalog lookups through `AppBranding` at access time.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites are `lilyTests/Shell/HomeContentTests.swift`
  and `lilyTests/Shell/HomeSegmentTests.swift`; the pane rule the segments draw is pinned in
  `lilyTests/Changes/ListStateTests.swift`).
