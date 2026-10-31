# Landing: ViewModels

Source: `lily/Features/Landing/ViewModels/`

## Overview

One observable view model drives the landing screen: the slides this build shows, the events the miniature screens draw
(the live upcoming preview once it arrived, the fixtures before and after a failure), the tournament whose bracket the
last slide draws, the slide on screen and the swipe hint, and the two ways into the app (guest, sign-in sheet). It is
main-actor isolated by the app target's default and depends on protocols (`EventRepository`, `Logging`) plus the
`SessionController`.

Files: `lily/Features/Landing/ViewModels/LandingViewModel.swift`.

## Interface

- `[LandingViewModel.swift:LandingViewModel]`: `@Observable final class LandingViewModel`. Stored state: `let slides =
  IntroSlide.shown()`; `private(set) var previewEvents: [SportEvent] = []`; `let sampleEvents: [SportEvent]`;
  `let sampleTournament: TournamentDetail`; `private(set) var currentSlide: IntroSlide = .first`;
  `private(set) var showsSwipeHint = true`; `var isSignInPresented = false`.
- `[LandingViewModel.swift:LandingViewModel.init]`: `init(session: SessionController, repository: any
  EventRepository, logger: any Logging, now: Date = .now)`; fills `sampleEvents` from `IntroFixtures.events(now:)` and
  `sampleTournament` from `IntroFixtures.tournament(now:)`.
- `[LandingViewModel.swift:LandingViewModel.introContent]`: `var introContent: IntroContent` =
  `IntroContent(events: previewEvents.isEmpty ? sampleEvents : previewEvents, tournament: sampleTournament)`.
- `[LandingViewModel.swift:LandingViewModel.loadPreview]`: `func loadPreview() async` loads the anonymous upcoming
  feed and keeps the first `AppConfig.Events.landingPreviewCount` events.
- `[LandingViewModel.swift:LandingViewModel.slideShown]`: `func slideShown(_ slide: IntroSlide?)`, the pager's report
  of the slide at rest.
- `[LandingViewModel.swift:LandingViewModel.enterApp]`: `func enterApp()` calls `session.continueAsGuest()`;
  `func presentSignIn()` sets `isSignInPresented = true`.

## Invariants

- `[LandingViewModel.swift:LandingViewModel.loadPreview]`: a failed load leaves `previewEvents` untouched, so the
  fixtures stay on screen and nothing is shown to the user; a cancelled load (`AppError.isCancellation(error)`) is not
  treated as a failure.
- `[LandingViewModel.swift:LandingViewModel.introContent]`: the tournament is always `sampleTournament`; only the events
  switch to live data, and only when at least one arrived.
- `[LandingViewModel.swift:LandingViewModel.slideShown]`: `guard let slide, slide != currentSlide else { return }`: a
  `nil` report (swipe in flight) or the same slide again (a rebound) changes nothing; `showsSwipeHint` goes `false`
  only on a real slide change and never comes back.
- `[LandingViewModel.swift:LandingViewModel.slides]`: fixed at construction from the build's feature flags
  (`IntroSlide.shown()` defaults); the list does not change while the landing is on screen.
- `[LandingViewModel.swift:LandingViewModel]`: `previewEvents`, `currentSlide` and `showsSwipeHint` are `private(set)`;
  views may only toggle `isSignInPresented` directly.

## Side Effects

- Network: `[LandingViewModel.swift:LandingViewModel.loadPreview]` calls `repository.events(in: .upcoming, near: nil)`
  (the anonymous upcoming read, no position) once per call; the view's `.task` owns the call and cancels it when the
  landing leaves.
- Logging: `[LandingViewModel.swift:LandingViewModel.loadPreview]` logs `.events` debug `"Landing preview load
  cancelled"` on cancellation and `.events` warning `"Landing preview unavailable: ..."` on any other error;
  `[LandingViewModel.swift:LandingViewModel.slideShown]` logs `.ui` debug `"Intro slide <rawValue> shown"`.
- Session: `[LandingViewModel.swift:LandingViewModel.enterApp]` calls `session.continueAsGuest()`, which moves the
  session state and so the root from the landing to the shell.
- No tasks are spawned here, nothing is written to disk or `UserDefaults`.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suite is
  `lilyTests/Landing/LandingViewModelTests.swift`).
