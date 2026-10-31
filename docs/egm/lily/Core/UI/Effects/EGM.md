# Effects

Source: `lily/Core/UI/Effects/`

## Overview

The arithmetic behind the aurora and the launch: pure, `nonisolated`, UI-free types a unit test drives with a time
value, the 4x4 mesh geometry (`AuroraGeometry`), the role layout and opacities of its cells (`AuroraRole`,
`AuroraPalette`), the process-wide fade-in curve (`AuroraReveal`) and the deterministic grain tiles (`FilmGrain`), plus
one main-actor UIKit switch, `LaunchAnimations`, which keeps UIKit's animations off from process start until the
shell's first frame has committed so the iOS 26 tab bar places its selection pill instead of sliding it. The views that
draw these (`AuroraBackground`, `FilmGrainOverlay`, `ContentScreen`) are in [Components](../Components/EGM.md); the
colors they map to are in [Theme](../Theme/EGM.md); every period, amplitude, opacity and seed is a
`DesignTokens.Aurora` constant in `lily/Config`.

## Interface

- `nonisolated enum AuroraGeometry` [`lily/Core/UI/Effects/AuroraGeometry.swift:AuroraGeometry`]:
  - `static let gridSize = 4`.
  - `static func points(at time: TimeInterval) -> [SIMD2<Float>]`: the 16 row-major mesh points inside the unit square;
    corners pinned, edge points slide along their edge, interior points drift on Lissajous sums
    (`DesignTokens.Aurora.driftPeriods`, `driftWeights`, `driftAmplitude`, `edgeDriftAmplitude`).
  - `static func cellIntensities(at time: TimeInterval) -> [Double]`: 16 row-major opacity multipliers, a main-diagonal
    ripple plus a weaker cross ripple (`ripplePeriod`, `rippleCrossPeriod`, `rippleSwing`, `rippleCrossSwing`,
    `rippleSpacing`); `.core` cells are also multiplied by `coreGlow(at:)`.
  - `static func coreGlow(at time: TimeInterval) -> Double`: `1 + DesignTokens.Aurora.glowSwing * sin(phase)` over
    `glowPeriod`.
  - `static func angle(at time: TimeInterval, period: TimeInterval) -> Float`: the reduced phase, narrowed to `Float`.
- `nonisolated enum AuroraRole: Equatable` [`lily/Core/UI/Effects/AuroraPalette.swift:AuroraRole`]: `.surface`,
  `.mass(MassDensity)`, `.core`, `.ember`; nested `enum MassDensity { case dense, mid, thin }`.
- `nonisolated enum AuroraPalette` [`lily/Core/UI/Effects/AuroraPalette.swift:AuroraPalette`]:
  `static let roles: [AuroraRole]`, the 16-entry row-major layout (row 0 `[.mass(.dense), .core, .mass(.mid),
  .surface]`, row 1 `[.mass(.dense), .mass(.dense), .mass(.thin), .surface]`, row 2 `[.surface, .mass(.thin),
  .mass(.mid), .mass(.dense)]`, row 3 `[.ember, .surface, .mass(.dense), .mass(.dense)]`);
  `static func massOpacity(_ density: AuroraRole.MassDensity) -> Double` maps to `DesignTokens.Aurora.massDense`,
  `massMid`, `massThin`.
- `nonisolated enum AuroraReveal` [`lily/Core/UI/Effects/AuroraReveal.swift:AuroraReveal`]: `static let start = Date()`;
  `static func opacity(at date: Date, start: Date = Self.start, duration: TimeInterval = DesignTokens.Aurora.revealDuration) -> Double`,
  0 at `start`, eased to 1 over `duration`, 1 from then on.
- `nonisolated enum FilmGrain` [`lily/Core/UI/Effects/FilmGrain.swift:FilmGrain`]:
  `static func pixels(size: Int, seed: UInt64) -> [UInt8]` (`size * size` row-major gray bytes from a seeded
  xorshift64); `static func makeImage(size: Int, seed: UInt64) -> CGImage?` (8-bit device gray, no alpha,
  `shouldInterpolate: false`); `static func frameIndex(at time: TimeInterval, frameCount: Int, frameRate: Double) -> Int`
  (which of `frameCount` tiles shows at `time`, switching `frameRate` times a second).
- `enum LaunchAnimations` [`lily/Core/UI/Effects/LaunchAnimations.swift:LaunchAnimations`], main-actor isolated
  (imports UIKit): `static func freeze(resumingAfter fallback: TimeInterval = AppConfig.Launch.animationsResumeFallback)`,
  called from `LilyAppDelegate`'s launch callback; `static func resumeAfterFirstFrame()`, called from
  `AppRootView`'s `.onAppear`.

## Invariants

- Phases are reduced modulo their period in `Double` before any `Float`:
  `time.truncatingRemainder(dividingBy: period) / period * 2 * .pi`
  [`lily/Core/UI/Effects/AuroraGeometry.swift:AuroraGeometry.reducedPhase`]. A `Float` phase built from
  `timeIntervalSinceReferenceDate` (about 8e8 s) would step by 8 to 32 rad and make `sin` snap.
- Mesh points: corners have zero amplitude, points on a vertical edge move only in y and on a horizontal edge only in x
  (`edgeDriftAmplitude`), interior points on both axes (`driftAmplitude`), decided by
  `column == 0 || column == lastIndex` and `row == 0 || row == lastIndex`
  [`lily/Core/UI/Effects/AuroraGeometry.swift:AuroraGeometry.driftAmplitude`]. Each point's phase is offset by
  `Float(index) * goldenAngle` with `goldenAngle = .pi * (3 - sqrt(5))`
  [`lily/Core/UI/Effects/AuroraGeometry.swift:AuroraGeometry.goldenAngle`]; drift angles are indexed
  `angles[(primary + rank) % angles.count]` [`lily/Core/UI/Effects/AuroraGeometry.swift:AuroraGeometry.wave`]. That the
  `driftWeights` sum to one and bound the amplitude is a property of `DesignTokens`, not checked here.
- `points(at:)` and `cellIntensities(at:)` always return exactly `gridSize * gridSize` = 16 elements, row-major
  (`row = index / gridSize`, `column = index % gridSize`); the breath factor applies only where
  `AuroraPalette.roles[index] == .core`, so `roles` must hold 16 entries
  [`lily/Core/UI/Effects/AuroraGeometry.swift:AuroraGeometry.cellIntensities(at:)`,
  `lily/Core/UI/Effects/AuroraPalette.swift:AuroraPalette.roles`].
- `AuroraReveal.opacity`: `guard duration > 0 else { return 1 }`; progress is
  `min(max(date.timeIntervalSince(start) / duration, 0), 1)`, eased by smoothstep `p * p * (3 - 2 * p)` (zero slope at
  both ends) [`lily/Core/UI/Effects/AuroraReveal.swift:AuroraReveal.opacity(at:start:duration:)`]. `start` is a lazy
  static evaluated once per process on first access, so every aurora on screen continues the same fade instead of
  restarting from black [`lily/Core/UI/Effects/AuroraReveal.swift:AuroraReveal.start`].
- `FilmGrain.pixels`: a zero seed is remapped to 1 (xorshift cannot leave a zero state); each byte is
  `UInt8(truncatingIfNeeded: state >> 24)` then `uniform * uniform / 255`, so most pixels stay dark; the same seed always
  gives the same tile [`lily/Core/UI/Effects/FilmGrain.swift:FilmGrain.pixels(size:seed:)`].
- `FilmGrain.frameIndex`: `time` is reduced by `truncatingRemainder(dividingBy: Double(frameCount) / frameRate)`, a
  negative remainder is wrapped by adding the loop, and the index is clamped to `frameCount - 1`; there is no guard for
  `frameRate == 0` or `frameCount == 0` [`lily/Core/UI/Effects/FilmGrain.swift:FilmGrain.frameIndex(at:frameCount:frameRate:)`].
  `makeImage` returns `nil` only when `CGDataProvider` or the failable `CGImage` initializer refuses the buffer
  [`lily/Core/UI/Effects/FilmGrain.swift:FilmGrain.makeImage(size:seed:)`].
- `LaunchAnimations.freeze` always schedules a fallback `resume()` after `fallback` seconds, so animations cannot stay
  off if the root never appears (an app without UIKit animations would be a worse fault than the sliding pill); there is
  no counter or re-entrancy guard, whichever of the fallback and `resumeAfterFirstFrame()` fires first turns them on
  [`lily/Core/UI/Effects/LaunchAnimations.swift:LaunchAnimations.freeze(resumingAfter:)`]. `resumeAfterFirstFrame()`
  defers by exactly one main-queue turn so the frame being built commits first
  [`lily/Core/UI/Effects/LaunchAnimations.swift:LaunchAnimations.resumeAfterFirstFrame()`]. SwiftUI's own animations
  are untouched.
- Isolation: `AuroraGeometry`, `AuroraRole`, `AuroraPalette`, `AuroraReveal` and `FilmGrain` are `nonisolated` and free
  of asset symbols, so they are `Sendable` and testable off the main actor; `LaunchAnimations` is main-actor isolated.

## Side Effects

- UIKit global state: `UIView.setAnimationsEnabled(false)` in `freeze`, `UIView.setAnimationsEnabled(true)` in the
  private `resume()` [`lily/Core/UI/Effects/LaunchAnimations.swift:LaunchAnimations.freeze(resumingAfter:)`,
  `lily/Core/UI/Effects/LaunchAnimations.swift:LaunchAnimations.resume`].
- Main-queue hops: `DispatchQueue.main.asyncAfter(deadline: .now() + fallback)` in `freeze`; `DispatchQueue.main.async`
  in `resumeAfterFirstFrame()` [`lily/Core/UI/Effects/LaunchAnimations.swift:LaunchAnimations`].
- Wall clock: `AuroraReveal.start` captures `Date()` once per process
  [`lily/Core/UI/Effects/AuroraReveal.swift:AuroraReveal.start`]; the time the geometry and grain functions take is
  passed in by the caller (`AuroraBackground`'s `TimelineView` date).
- Randomness: `FilmGrain` uses a seeded xorshift64 (`x ^= x << 13; x ^= x >> 7; x ^= x << 17`), fully deterministic;
  no `SystemRandomNumberGenerator` [`lily/Core/UI/Effects/FilmGrain.swift:FilmGrain.nextState`].
- Allocation: `FilmGrain.makeImage` allocates a `Data` buffer, a `CGDataProvider` and a `CGImage` on each call; nothing
  here caches (`FilmGrainOverlay` in Components builds its tiles once as a static)
  [`lily/Core/UI/Effects/FilmGrain.swift:FilmGrain.makeImage(size:seed:)`].
- No logging, no I/O, no network.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites are `lilyTests/UI/AuroraGeometryTests.swift`,
  `AuroraRevealTests.swift`, `FilmGrainTests.swift` and `LaunchAnimationsTests.swift`). The rendered aurora, grain and
  the launch pill are checked by screenshot and recording on a simulator per `AGENTS.md` (evidence in
  `docs/notes/design-and-ui.md` and `docs/notes/shell-and-navigation.md`).
