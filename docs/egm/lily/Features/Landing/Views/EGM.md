# Landing: Views

Source: `lily/Features/Landing/Views/`

## Overview

The first screen: a vertical, page-snapping intro of full-page slides over the aurora, each a framed miniature of a real
app screen (Explore's cards, an event detail down to Join, a group room, a tournament bracket) with a two-line caption,
a trailing page indicator and the two entry buttons pinned under every slide. The miniatures are pictures (fixed type
size, no hit testing, hidden from VoiceOver); the real views they reuse (`EventCard`, `EventFactsCard`, `BracketView`,
`AvatarCircle`, `ScreenTitle`) live in other features and `Core/UI`.

Files: `lily/Features/Landing/Views/LandingView.swift`, `lily/Features/Landing/Views/IntroPager.swift`,
`lily/Features/Landing/Views/IntroSlideView.swift`, `lily/Features/Landing/Views/IntroScreenFrame.swift`,
`lily/Features/Landing/Views/IntroScreens.swift`, `lily/Features/Landing/Views/IntroPageIndicator.swift`.

## Interface

- `[LandingView.swift:LandingView]`: `init(dependencies: AppDependencies)`; `@State viewModel` from
  `dependencies.makeLandingViewModel()`, `@State visibleSlide: IntroSlide? = .first`. Draws `AuroraBackground(intensity:
  DesignTokens.Aurora.landingIntensity)` under a `VStack` of `IntroPager` (with `IntroPageIndicator` as a trailing
  overlay) and `actions`: `Button(AppBranding.landingPrimaryAction)` with `lilyProminentButton()` and
  `Button(AppBranding.signInAction)` with `lilyGlassButton(labelColor: .lilyInk)` in a `GlassEffectContainer`, under
  `.readableColumn(maxWidth: DesignTokens.Layout.landingButtonMaxWidth)`. Presents `SignInSheet(session:errorCenter:)`
  as a sheet bound to `viewModel.isSignInPresented`.
- `[LandingView.swift:LandingHeadline]`: `lines: [String]`; one `HeadlineLine` per line, the last in `Color.lilyAccent`,
  the others `Color.lilyInk`; `.fixedSize(horizontal: false, vertical: true)`, `.accessibilityElement(children:
  .combine)`. `[LandingView.swift:HeadlineLine]` is `private`: a `ViewThatFits(in: .horizontal)` of one line at scale 1,
  one line at `DesignTokens.Layout.headlineMinimumScale`, then a wrapped line; font `LilyTheme.Fonts.headline(scale:)`,
  tracking `DesignTokens.Typography.headlineTracking * scale`.
- `[IntroPager.swift:IntroPager]`: `slides: [IntroSlide]`, `content: IntroContent`, `showsSwipeHint: Bool`, `@Binding
  visibleSlide: IntroSlide?`; reads `\.dynamicTypeSize` and `\.motion` (`MotionPreference`, `lily/Core/UI/Layout`). A vertical `ScrollView` of
  `IntroSlideView`s with `.scrollTargetLayout()`, `.scrollPosition(id: $visibleSlide)`, `.scrollIndicators(.hidden)`
  and `.accessibilityIdentifier(AccessibilityIdentifiers.introPager)`; `nonisolated private static func
  leavingScale(_: ScrollTransitionPhase, allowsMovement: Bool) -> CGFloat`.
- `[IntroSlideView.swift:IntroSlideView]`: `slide: IntroSlide`, `content: IntroContent`, `showsSwipeHint: Bool`; reads
  `\.dynamicTypeSize` and `\.horizontalSizeClass`; `stacked` (compact) or `sideBySide` (regular) layouts;
  `.accessibilityElement(children: .contain)` then `.accessibilityIdentifier(AccessibilityIdentifiers.introSlide(slide))`.
  `screen` maps `.events` to `IntroExploreScreen(events:)`, `.join` to `IntroDetailScreen(event:)` (only when
  `content.joinEvent` exists), `.groups` to `IntroChatScreen(eventTitle:)`, `.tournaments` to
  `IntroTournamentScreen(detail:)`. `[IntroSlideView.swift:SwipeHint]` is `private`: `Label(AppBranding.Intro.swipeHint,
  systemImage: DesignTokens.Symbols.swipeUp)` at `@ScaledMetric(relativeTo: .footnote)` height
  `DesignTokens.Layout.introHintRowHeight`; reads `\.motion` and bounces only while `isShown && motion.allowsMovement`.
- `[IntroScreenFrame.swift:IntroScreenFrame]`: `struct IntroScreenFrame<Content: View>` with `fadesBottom = true`,
  `alignment: Alignment = .top`, `width: CGFloat = DesignTokens.Layout.introScreenWidth`, `@ViewBuilder content`;
  `@State contentHeight`, `frameHeight`. Applies `.dynamicTypeSize(DesignTokens.Layout.introScreenTypeSize)`, a
  `Color.lilySurface.opacity(DesignTokens.Opacity.introScreenFill)` fill, a `DesignTokens.Radius.screen` stroke at
  `DesignTokens.Opacity.introScreenStroke` / `DesignTokens.Layout.introScreenStrokeWidth`, a gradient `mask`,
  `.allowsHitTesting(false)` and `.accessibilityHidden(true)`.
- `[IntroScreens.swift:IntroExploreScreen]`: `events: [SportEvent]`; `ScreenTitle(text: AppBranding.exploreTitle)` and
  an `EventCard` per event.
- `[IntroScreens.swift:IntroDetailScreen]`: `event: SportEvent`; `EventTypeChip`, `ScreenTitle(text: event.title,
  subtitle: AppBranding.hostedByTitle(for: event.hostName))`, `EventFactsCard` with `.frame(maxHeight: .infinity)`, and
  `Button(AppBranding.joinAction) {}` with `lilyProminentButton()` overlaid by the private `TapPulse`.
- `[IntroScreens.swift:IntroChatScreen]`: `eventTitle: String`; a header (`AvatarCircle`, `IntroFixtures.groupName`,
  `AppBranding.Groups.members(IntroFixtures.memberCount)`), bubbles for `AppBranding.Intro.Chat.question`, `.answer`
  and `.followUp` through `bubbleFill(own:)`, the system line `AppBranding.Chat.eventCreated(by:title:)`, and a
  composer (`AppBranding.Chat.placeholder` in `lilyMultilineField()`, `DesignTokens.Symbols.send` in `lilyIconButton()`).
- `[IntroScreens.swift:IntroTournamentScreen]`: `detail: TournamentDetail`; `EventTypeChip`, `TournamentStatusChip`,
  `ScreenTitle(text: detail.tournament.name, subtitle: AppBranding.Tournaments.organizedBy(name:))` and
  `BracketView(detail:) { _ in }`.
- `[IntroScreens.swift:TapPulse]`: `private`; reads `\.motion` and `\.auroraFrozen`, `@State
  startedAt: Date?`; a `TimelineView(.animation(minimumInterval: DesignTokens.Aurora.frameInterval, paused: startedAt ==
  nil))` drawing a `Circle().strokeBorder(Color.white, lineWidth: DesignTokens.Layout.introPulseLineWidth)` of
  `DesignTokens.Layout.controlHeight` scaled and faded by `TapPulseCurve.intro.frame(elapsed:)`.
- `[IntroPageIndicator.swift:IntroPageIndicator]`: `slides: [IntroSlide]`, `current: IntroSlide`; one `Capsule` per
  slide, `DesignTokens.Layout.introPageBarThickness` wide, `introPageBarActiveLength` or `introPageBarLength` long,
  `.lilyAccent` or `.lilyInk.opacity(DesignTokens.Opacity.introPageBarInactive)`; `.accessibilityHidden(true)`.

## Invariants

- `[LandingView.swift:LandingView.body]`: `.ignoresSafeArea(.keyboard)` on the whole screen, so the sign-in sheet's
  keyboard never shrinks the pager's page.
- `[IntroPager.swift:IntroPager.pages]`: paging (`.scrollTargetBehavior(.paging)` and a page height equal to the
  pager's own measured height) only while `!typeSize.isAccessibilitySize`; at accessibility sizes the feed is a plain
  scroll of natural heights. The height comes from the `GeometryReader`, never `containerRelativeFrame`.
- `[IntroPager.swift:IntroPager.feed]`: `motion.allowsMovement` is copied to a local before the `scrollTransition`
  closure, which runs off the main actor; a leaving slide gets `DesignTokens.Opacity.introSlideLeaving` and
  `DesignTokens.Layout.introSlideLeavingScale`, or scale 1 when movement is not allowed (`leavingScale`).
- `[IntroPager.swift:IntroPager.feed]`: the swipe hint is passed as `showsSwipeHint && slide == slides.first`, so only
  the first slide ever shows it.
- `[IntroSlideView.swift:IntroSlideView.frame]`: the frame crops at `.bottom` and does not fade when
  `slide.keepsBottom`, crops at `.top` and fades its bottom otherwise; the miniature has `layoutPriority(-1)` and a
  maximum height of `introScreenWidth * introScreenMaxAspect` (compact) or `introScreenWideWidth *
  introScreenWideAspect` (regular), and a fixed `introScreenAccessibilityHeight` at accessibility type sizes.
- `[IntroScreenFrame.swift:IntroScreenFrame.fadesTop]`: the top fades only when `alignment == .bottom && frameHeight >
  0 && contentHeight > frameHeight + DesignTokens.Layout.introScreenOverflowTolerance`; the mask's top stop is capped
  so it never crosses the bottom fade.
- `[IntroScreens.swift:TapPulse.body]`: nothing is drawn when `!motion.allowsMovement || auroraFrozen` (the environment the
  `-freeze-aurora` launch argument sets); the clock starts on `onScrollVisibilityChange(threshold:
  DesignTokens.Layout.introPulseVisibilityThreshold)` (`startedAt = isVisible ? .now : nil`), not on `onAppear`.
- `[IntroScreens.swift:IntroDetailScreen]`, `[IntroScreens.swift:IntroChatScreen.composer]`: the Join and send buttons
  have empty actions; with `IntroScreenFrame`'s `allowsHitTesting(false)` the miniatures take no taps.
- `[LandingView.swift:LandingHeadline]`: the last headline line is always the accent colour; `HeadlineLine` never
  truncates (one line, shrunk one line, or wrapped).

## Side Effects

- `[LandingView.swift:LandingView.body]`: no request is made from the landing; `.onChange(of: visibleSlide) { viewModel.slideShown(visibleSlide) }` (logs at debug
  through the view model); the buttons call `viewModel.enterApp()` (guest session) and `viewModel.presentSignIn()`.
- `[IntroScreens.swift:TapPulse]`: a wall-clock `TimelineView` at `DesignTokens.Aurora.frameInterval` reading
  `context.date` while the ring is visible; `AuroraBackground` under the landing runs its own clock.
- Animations: `[IntroPageIndicator.swift:IntroPageIndicator]` `.animation(.smooth(duration:
  DesignTokens.Duration.normal), value: current)`; `[IntroSlideView.swift:SwipeHint]` `.animation(.easeOut(duration:
  DesignTokens.Duration.normal), value: isShown)` and `.symbolEffect(.bounce.up, options:
  .repeat(.periodic(delay: DesignTokens.Duration.introHintBouncePause)))`; `[IntroPager.swift:IntroPager.feed]`
  `.scrollTransition(.interactive)`.
- `[IntroScreenFrame.swift:IntroScreenFrame.body]`: two `onGeometryChange` observers write `contentHeight` and
  `frameHeight` state.
- `[LandingView.swift:LandingView.body]`: presents `SignInSheet`, which mounts its own `.errorPopup`.
- No disk, `UserDefaults`, logging or network calls are made directly by these views.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the model and view-model suites under `lilyTests/Landing` cover
  the logic these views draw; the screens themselves are exercised by the UI tests, `./scripts/ci.sh ui`).
