# Push

Source: `lily/Core/Push/`

## Overview

Push notifications for game and match reminders. `PushCoordinator` keeps Laurel's device registry in step with this
device (`PUT`/`DELETE` through `DeviceRepository`), asks for the permission at the right moment (after the user
committed to a game, through `PushOptIn`), and opens the event or match behind a tapped reminder. A registration is
repeated only when the token, the user or the app's language changed or the last one is older than
`AppConfig.Push.reregisterInterval`, and is undone before a sign-out while the Bearer is still sent. Failures are
logged, never shown. The system calls (`UNUserNotificationCenter`, APNs registration) sit behind `PushRegistrar`, so
the `-mock-events` run never meets the permission alert.

## Interface

- Children: [Interfaces](./Interfaces/EGM.md) (`DeviceRepository`, `PushRegistrar`, `PushOptIn`),
  [Models](./Models/EGM.md) (`DeviceRegistrationPayload`, `LastDeviceRegistration`, `PushAuthorization`,
  `PushRegistrationError`, `PushEnvironment`, `PushTap`, `PushPayload`), [Implementations](./Implementations/EGM.md)
  (`SystemPushRegistrar`, `RemoteDeviceRepository`, `PushEventRelay`, the mocks).
- `final class PushCoordinator: SessionObserver, PushOptIn` (main-actor): `private(set) var registered: LastDeviceRegistration?`,
  `private(set) var pendingTap: PushTap?`;
  `init(registrar: any PushRegistrar, devices: any DeviceRepository, identity: any IdentityProvider, opener: EventOpener, tournamentOpener: TournamentOpener, relay: PushEventRelay = .shared, defaults: UserDefaults, appVersion: AppVersion = .current(), languageCode: @escaping () -> String, unregisterTimeout: Duration = AppConfig.Push.unregisterTimeout, sleep: @escaping Sleep = systemSleep, logger: any Logging, now: @escaping () -> Date = { .now })`
  [`lily/Core/Push/PushCoordinator.swift:PushCoordinator`].
- `func sync() async` (every shell sync for a signed-in user), `func offerReminders() async`,
  `func handleTap(_ tap: PushTap)`, `func openPendingTap() async`, `func sessionWillEnd() async`,
  `func sessionDidEnd()` [`lily/Core/Push/PushCoordinator.swift:PushCoordinator.sync()`].

## Invariants

- `init` loads `registered` from `defaults.data(forKey: AppConfig.Push.lastRegistrationKey)` (JSON) and installs
  itself as `relay.tapHandler`, so a tap held by the relay before the composition root existed is delivered at once
  [`PushCoordinator.swift:PushCoordinator.init`, `PushCoordinator.swift:PushCoordinator.loadRegistration(from:)`].
- `sync()` registers only when `identity.currentUserID` is set, `registrar.authorization()` is `.authorized`, and the
  system has not refused a token in this process (`tokenRefused`); each skip is a debug line
  [`PushCoordinator.swift:PushCoordinator.sync()`].
- `offerReminders()` asks only when signed in and the authorization is `.notDetermined`; a grant calls `sync()` at
  once; the system remembers the answer, so later calls are no-ops [`PushCoordinator.swift:PushCoordinator.offerReminders()`].
- One registration in flight: a `sync()` made meanwhile joins the running `registration` task
  [`PushCoordinator.swift:PushCoordinator.register(for:)`].
- A registration is skipped when `registered.isCurrent(token:userID:locale:now:within: AppConfig.Push.reregisterInterval)`.
  The payload is `platform: AppConfig.Push.platform`, `environment: .current` (sandbox for Debug and Staging,
  production for Release), `appVersion: appVersion.headerValue`,
  `locale: languageCode()`. The answer is stored only if `identity.isStillCaller(userID, orDrop:)` still holds. A
  `PushRegistrationError.refused` sets `tokenRefused` for the rest of the process; a cancellation is silent; any other
  failure is a warning [`PushCoordinator.swift:PushCoordinator.performRegistration(for:)`].
- `handleTap` keeps the tap in `pendingTap` and opens it in a task when a user is signed in; `openPendingTap` needs a
  signed-in user, clears the tap, and opens `.event` through `opener.open(eventID:from: "a notification")` and `.match`
  through `tournamentOpener.open(tournamentID:matchID:from:)` [`PushCoordinator.swift:PushCoordinator.handleTap(_:)`, `PushCoordinator.swift:PushCoordinator.openPendingTap()`].
- `sessionWillEnd()` runs only when a registration is stored or in flight; it awaits the in-flight registration
  (never cancels it, since a cancelled PUT may have landed), then unregisters the set of the token known before and the
  token stored meanwhile; the whole is bounded by `Deadline.within(unregisterTimeout, sleep:, orThrow: .timedOut)`;
  any failure is a warning; the stored registration is cleared regardless
  [`PushCoordinator.swift:PushCoordinator.sessionWillEnd()`, `PushCoordinator.swift:PushCoordinator.unregister(tokens:)`].
- `sessionDidEnd()` clears the stored registration and the pending tap [`PushCoordinator.swift:PushCoordinator.sessionDidEnd()`].

## Side Effects

- `UserDefaults` under `AppConfig.Push.lastRegistrationKey`: JSON of `LastDeviceRegistration` set, or the key removed
  [`PushCoordinator.swift:PushCoordinator.store(_:)`].
- Network through `DeviceRepository`: `register(_:)`, `unregister(token:)`
  [`PushCoordinator.swift:PushCoordinator.performRegistration(for:)`, `PushCoordinator.swift:PushCoordinator.unregister(tokens:)`].
- System: `registrar.authorization()`, `requestAuthorization()`, `deviceToken()` (the permission prompt and APNs
  registration behind the seam) [`PushCoordinator.swift:PushCoordinator.offerReminders()`].
- Navigation through `EventOpener` and `TournamentOpener` [`PushCoordinator.swift:PushCoordinator.openPendingTap()`].
- Tasks: the `registration` task; `Task { await openPendingTap() }` from `handleTap`
  [`PushCoordinator.swift:PushCoordinator.register(for:)`, `PushCoordinator.swift:PushCoordinator.handleTap(_:)`].
- Logging under `.push`: debug "Device not registered: notifications not authorized", "Device not registered: the
  system refused a token this launch", "Device registration still current"; info "Notification permission granted",
  "Notification permission declined", "Notification tapped for <logName>", "Device registered for push
  (<environment>, <locale>)", "Device unregistered for push"; warning "Device registration failed", "Device
  unregistration failed" [`PushCoordinator.swift:PushCoordinator`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Push`)
