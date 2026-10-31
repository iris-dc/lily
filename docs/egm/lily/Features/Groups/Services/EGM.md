# Groups Services

Source: `lily/Features/Groups/Services/`

## Overview

One nineteen-line class. `GroupErrorReporter` is the funnel every groups view model in
[ViewModels](../ViewModels/EGM.md) hands its failures to: it normalises the error to an `AppError`, forwards it to the
shared `ErrorCenter` (the one popup), and, when the backend refused the write because the terms are not accepted, calls
back so the composition root can raise the terms sheet. It holds no observable state and conforms to no protocol.

## Interface

- `final class GroupErrorReporter` (not `@Observable`, no protocol conformances)
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter`].
- `init(errorCenter: ErrorCenter, onTermsRequired: @escaping @MainActor () -> Void)`
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.init`].
- `report(_ error: any Error)` [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.report`].

## Invariants

- Every reported error is normalised with `AppError.wrapping(error)` before it reaches `ErrorCenter`
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.report`].
- `onTermsRequired` fires only when the wrapped error `== .termsRequired`, and always after `errorCenter.report`
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.report`].
- The callback is typed `@MainActor () -> Void`; the class itself is main-actor isolated under the target's default
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.init`].

## Side Effects

- `errorCenter.report(appError)` on every call to `report`
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.report`].
- Invokes the injected `onTermsRequired()` when the error is `.termsRequired`
  [`lily/Features/Groups/Services/GroupErrorReporter.swift`:`GroupErrorReporter.report`].
- No network, disk, `UserDefaults`, logging, `Task`, timer or notification use.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the view-model suites under `lilyTests/Groups` exercise the
  reporter, for example `GroupDetailViewModelTests` and `MembersViewModelTests`).
