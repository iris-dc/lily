# Push Models

Source: `lily/Core/Push/Models/`

## Overview

The wire and state values of push notifications: the device registration body and answers, what this device last told
the backend, the permission and registration-error enums, the APNs environment, and the reader of a tapped
notification's payload. Every type is `nonisolated` and `Sendable`; none performs I/O.

## Interface

- `nonisolated struct DeviceRegistrationPayload: Encodable, Equatable, Sendable`: `token`, `platform`,
  `environment: PushEnvironment`, `appVersion`, `locale` (all `String` but the environment); the body of
  `PUT /api/me/devices` per its doc comment [`lily/Core/Push/Models/DeviceRegistration.swift:DeviceRegistrationPayload`].
- `nonisolated struct DeviceRegistration: Decodable, Equatable, Sendable`: `token`, `environment: PushEnvironment`,
  `registeredAt: Date` [`lily/Core/Push/Models/DeviceRegistration.swift:DeviceRegistration`].
- `nonisolated struct DeviceRemoval: Decodable, Equatable, Sendable`: `token`, `removed: Bool`
  [`lily/Core/Push/Models/DeviceRegistration.swift:DeviceRemoval`].
- `nonisolated struct LastDeviceRegistration: Codable, Equatable, Sendable`: `token`, `userID`, `locale: String?`,
  `registeredAt: Date`; `func isCurrent(token:userID:locale:now:within interval: TimeInterval) -> Bool`
  [`lily/Core/Push/Models/DeviceRegistration.swift:LastDeviceRegistration`].
- `nonisolated enum PushAuthorization: Sendable`: `.notDetermined`, `.denied`, `.authorized`
  [`lily/Core/Push/Models/PushAuthorization.swift:PushAuthorization`].
- `nonisolated enum PushRegistrationError: Error, Equatable, Sendable`: `.refused(String)`, `.timedOut`
  [`lily/Core/Push/Models/PushAuthorization.swift:PushRegistrationError`].
- `nonisolated enum PushEnvironment: String, Codable, Sendable`: `.sandbox`, `.production`; `static var current`
  [`lily/Core/Push/Models/PushEnvironment.swift:PushEnvironment`].
- `nonisolated enum PushTap: Hashable, Sendable`: `.event(id: String)`, `.match(tournamentID: String, matchID: String)`;
  `var logName: String` (ids only) [`lily/Core/Push/Models/PushPayload.swift:PushTap`].
- `nonisolated enum PushPayload`: `static func tap(from userInfo: [AnyHashable: Any]) -> PushTap?`
  [`lily/Core/Push/Models/PushPayload.swift:PushPayload`].

## Invariants

- `LastDeviceRegistration.isCurrent` is true only when `token`, `userID` and `locale` all equal the arguments and
  `now - registeredAt < interval`; `locale` is optional because registrations stored before the app spoke more than
  one language have none, and a `nil` stored locale never compares equal to a current one
  [`DeviceRegistration.swift:LastDeviceRegistration.isCurrent(token:userID:locale:now:within:)`].
- `PushEnvironment.current` is `.sandbox` under `#if DEBUG` and `.production` otherwise
  [`PushEnvironment.swift:PushEnvironment.current`].
- `PushPayload.tap(from:)` reads `AppConfig.Push.Payload.kind`; `eventReminder` needs `AppConfig.Push.Payload.eventID`,
  `matchReminder` needs both `tournamentID` and `matchID`; an empty string counts as missing; any other kind or a
  missing id answers `nil`. Only strings are read, so the result can cross to the main actor
  [`PushPayload.swift:PushPayload.tap(from:)`, `PushPayload.swift:PushPayload.value(_:_:)`].
- `PushRegistrationError.refused` is `didFailToRegisterForRemoteNotifications`; `.timedOut` means neither callback came
  within `AppConfig.Push.tokenTimeout` [`PushAuthorization.swift:PushRegistrationError`].

## Side Effects

- None (pure values).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Push`)
