# Push Models

Source: `lily/Core/Push/Models/`

## Overview

The wire and state values of push notifications: the device registration body and answers, what this device last told
the backend, the permission and registration-error enums, the APNs environment, and the reader of a tapped
notification's payload. Every type is `nonisolated` and `Sendable`; none performs I/O.

## Interface

- `nonisolated struct DeviceRegistrationPayload: Encodable, Equatable, Sendable`: `token`, `platform`,
  `environment: PushEnvironment`, `appVersion`, `locale` (all `String` but the environment) and
  `mutedKinds: [String]` (sorted, empty when everything may come, 2026-11-26); the body of
  `PUT /api/me/devices` per its doc comment [`lily/Core/Push/Models/DeviceRegistration.swift:DeviceRegistrationPayload`].
- `nonisolated struct DeviceRegistration: Decodable, Equatable, Sendable`: `token`, `environment: PushEnvironment`,
  `registeredAt: Date` [`lily/Core/Push/Models/DeviceRegistration.swift:DeviceRegistration`].
- `nonisolated struct DeviceRemoval: Decodable, Equatable, Sendable`: `token`, `removed: Bool`
  [`lily/Core/Push/Models/DeviceRegistration.swift:DeviceRemoval`].
- `nonisolated struct LastDeviceRegistration: Codable, Equatable, Sendable`: `token`, `userID`, `locale: String?`,
  `mutedKinds: [String]?` (2026-11-26), `registeredAt: Date`;
  `func isCurrent(for payload: DeviceRegistrationPayload, userID:now:within interval: TimeInterval) -> Bool`
  [`lily/Core/Push/Models/DeviceRegistration.swift:LastDeviceRegistration`].
- `nonisolated enum NotificationKind: String, CaseIterable, Sendable` (2026-11-26): `.eventReminder`,
  `.matchReminder`, `.eventCancelled`; `wireName` = the raw value, Laurel's payload kinds
  [`lily/Core/Push/Models/NotificationKind.swift:NotificationKind`].
- `nonisolated enum PushAuthorization: Sendable`: `.notDetermined`, `.denied`, `.authorized`
  [`lily/Core/Push/Models/PushAuthorization.swift:PushAuthorization`].
- `nonisolated enum PushRegistrationError: Error, Equatable, Sendable`: `.refused(String)`, `.timedOut`
  [`lily/Core/Push/Models/PushAuthorization.swift:PushRegistrationError`].
- `nonisolated enum PushEnvironment: String, Codable, Sendable`: `.sandbox`, `.production`; `static var current`;
  `static func forBuild(_ configuration: AppConfig.Build.Configuration) -> PushEnvironment`
  [`lily/Core/Push/Models/PushEnvironment.swift:PushEnvironment`].
- `nonisolated enum PushTap: Hashable, Sendable`: `.event(id: String)`, `.match(tournamentID: String, matchID: String)`;
  `var logName: String` (ids only) [`lily/Core/Push/Models/PushPayload.swift:PushTap`].
- `nonisolated enum PushPayload`: `static func tap(from userInfo: [AnyHashable: Any]) -> PushTap?`
  [`lily/Core/Push/Models/PushPayload.swift:PushPayload`].

## Invariants

- `LastDeviceRegistration.isCurrent` is true only when the stored `token`, `locale` and mutes equal the payload's,
  `userID` equals the argument and `now - registeredAt < interval`; `locale` and `mutedKinds` are optional because
  rows stored by older builds lack them — a `nil` locale never compares equal to a current one, while `nil` mutes
  read as none (2026-11-26)
  [`DeviceRegistration.swift:LastDeviceRegistration.isCurrent(for:userID:now:within:)`].
- `PushEnvironment.forBuild` is `.production` for `.release` alone and `.sandbox` for `.debug` and `.staging` (every
  build run from Xcode is development-signed and holds a sandbox token); `current` is
  `forBuild(AppConfig.Build.configuration)` [`PushEnvironment.swift:PushEnvironment.forBuild(_:)`].
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
