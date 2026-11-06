# Landing: Models

Source: `lily/Features/Landing/Models/`

## Overview

Plain data behind the landing's intro pager: which slides a build shows and in what order, the content the slides'
miniature screens draw, the arithmetic of the ring that pulses over the join slide's button, and the fixtures the
miniatures always draw (never a live answer). Every type is `nonisolated` and `Sendable`; nothing here performs I/O.

Files: `lily/Features/Landing/Models/IntroSlide.swift`, `lily/Features/Landing/Models/TapPulseCurve.swift`,
`lily/Features/Landing/Models/IntroFixtures.swift`.

## Interface

- `[IntroSlide.swift:IntroSlide]`: `nonisolated enum IntroSlide: String, CaseIterable, Identifiable, Sendable` with cases
  `events`, `join`, `groups`, `tournaments` (declaration order is swipe order); `static let first: IntroSlide = .events`;
  `var id: String { rawValue }`; `var headline: [String]` reads `AppBranding.Intro.headline(for: self)`;
  `var keepsBottom: Bool` is `true` for `.join` and `.groups`, `false` for `.events` and `.tournaments`.
- `[IntroSlide.swift:IntroSlide.shown]`: `static func shown(groups: Bool = AppConfig.FeatureFlags.groups &&
  AppConfig.FeatureFlags.chat, tournaments: Bool = AppConfig.FeatureFlags.tournaments) -> [IntroSlide]` filters
  `allCases` by the two flags.
- `[IntroSlide.swift:IntroContent]`: `nonisolated struct IntroContent: Equatable, Sendable` with `let events:
  [SportEvent]`, `let joinEvent: SportEvent?`, `let tournament: TournamentDetail`; `init(events: [SportEvent],
  tournament: TournamentDetail)` derives `joinEvent`.
- `[TapPulseCurve.swift:TapPulseCurve]`: `nonisolated struct TapPulseCurve: Equatable, Sendable` with `period:
  TimeInterval`, `activeFraction`, `fadeInFraction`, `maxScale`, `peakOpacity: Double`; nested `struct Frame:
  Equatable, Sendable { scale: Double; opacity: Double }` with `static let resting = Frame(scale: 1, opacity: 0)`.
- `[TapPulseCurve.swift:TapPulseCurve.intro]`: `static let intro` built from `DesignTokens.Duration.introPulsePeriod`,
  `DesignTokens.Layout.introPulseActiveFraction`, `DesignTokens.Layout.introPulseFadeInFraction`,
  `DesignTokens.Layout.introPulseScale` and `DesignTokens.Opacity.introPulse`.
- `[TapPulseCurve.swift:TapPulseCurve.phase]`: `func phase(elapsed: TimeInterval) -> Double`;
  `func frame(elapsed: TimeInterval) -> Frame`; `func frame(atPhase phase: Double) -> Frame`.
- `[IntroFixtures.swift:IntroFixtures]`: `nonisolated enum IntroFixtures` with `static let groupName = "Kreuzberg
  Kickers"`, `static let memberCount = 12`, `static let senderName = MockChatFixtures.senders[0]`;
  `static func events(now: Date) -> [SportEvent]` returns `MockEventFixtures.make(now: now, count:
  AppConfig.Events.introSampleEventCount)`; `static func tournament(now: Date) -> TournamentDetail` builds
  `MockTournamentFixtures.kickersCup(now:organizerUserID:organizerName:)`, starts it (`.starting(at: now)`) and settles
  the two results in `private static let semiFinals` (`TournamentSchedule.matchID(round: 1, position: 1)` 3:1 and
  `(round: 1, position: 2)` 2:0).

## Invariants

- `[IntroSlide.swift:IntroSlide.shown]`: `.events` and `.join` are always shown; `.groups` only when both the `groups`
  and the `chat` flags are on; `.tournaments` only with the `tournaments` flag. The result keeps `allCases` order.
- `[IntroSlide.swift:IntroContent.init]`: `joinEvent = events.first { !$0.isFull } ?? events.first`, so it is `nil` only
  when `events` is empty; `tournament` is stored as given.
- `[TapPulseCurve.swift:TapPulseCurve.phase]`: the result is in `0 ..< 1` and wraps every `period`
  (`truncatingRemainder`, a negative remainder shifted by `+ period`).
- `[TapPulseCurve.swift:TapPulseCurve.frame(atPhase:)]`: `guard phase < activeFraction else { return .resting }`; the
  scale is `1 + (maxScale - 1) * eased` with a quadratic ease-out; the opacity is `peakOpacity * min(fadeIn, fadeOut)`,
  linear in and out. Pure arithmetic over the inputs, no stored state.
- `[IntroFixtures.swift:IntroFixtures.tournament]`: the organiser is `MockGroupFixtures.memberID(for: senderName)`,
  never the mock caller; a result whose match is missing is skipped (`guard let match = detail.match(id:) else { return
  detail }`).
- `[IntroFixtures.swift:IntroFixtures]`: the group name is a proper noun and is deliberately not localized; every other
  string the intro shows comes from `AppBranding`.
- `[IntroSlide.swift:IntroSlide]`, `[TapPulseCurve.swift:TapPulseCurve]`, `[IntroFixtures.swift:IntroFixtures]`: all
  declared `nonisolated`, so they are usable from non-main-actor code and stay `Sendable`.

## Side Effects

- None. No I/O, logging, tasks or clocks: `[IntroFixtures.swift:IntroFixtures.events]` and
  `[IntroFixtures.swift:IntroFixtures.tournament]` are deterministic for a given `now`, and
  `[TapPulseCurve.swift:TapPulseCurve.frame(elapsed:)]` takes the elapsed time as a parameter.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites are `lilyTests/Landing/IntroSlideTests.swift`
  and `lilyTests/Landing/TapPulseCurveTests.swift`).
