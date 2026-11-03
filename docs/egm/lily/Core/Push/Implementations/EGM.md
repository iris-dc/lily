# Push Implementations

Source: `lily/Core/Push/Implementations/`

## Overview

The conformers of `../Interfaces/EGM.md` and the relay that joins the UIKit app delegate to the coordinator.
`SystemPushRegistrar` and `RemoteDeviceRepository` are the production pair; `MockPushRegistrar`,
`MockDeviceRepository` and `NoPushOptIn` serve the `-mock-events` run, previews and tests. `PushEventRelay` exists
because the delegate is created by SwiftUI before the composition root, so the delegate posts to the shared relay and
`PushCoordinator` (`../EGM.md`) subscribes. All classes are main-actor under the app target's default isolation.

## Interface

- `final class PushEventRelay`: `static let shared`; `var tapHandler: ((PushTap) -> Void)?`;
  `init(sleep: @escaping Sleep = systemSleep)`;
  `func token(timeout: Duration, register: () -> Void) async throws -> String`; `func deliver(token: Data)`;
  `func fail(_ error: any Error)`; `func notificationTapped(_ tap: PushTap)`
  [`lily/Core/Push/Implementations/PushEventRelay.swift:PushEventRelay`].
- `final class SystemPushRegistrar: PushRegistrar`: `init(relay: PushEventRelay = .shared, logger: any Logging)`
  [`lily/Core/Push/Implementations/SystemPushRegistrar.swift:SystemPushRegistrar`].
- `final class RemoteDeviceRepository: DeviceRepository`: `init(client: any APIClient)`
  [`lily/Core/Push/Implementations/RemoteDeviceRepository.swift:RemoteDeviceRepository`].
- `final class MockDeviceRepository: DeviceRepository`: `private(set) var registrations: [DeviceRegistrationPayload]`;
  `init(identity: any IdentityProvider, logger: any Logging)` (`registeredAt` is `.now`)
  [`lily/Core/Push/Implementations/MockDeviceRepository.swift:MockDeviceRepository`].
- `final class MockPushRegistrar: PushRegistrar`: `private(set) var status: PushAuthorization` (starts
  `.notDetermined`); `init(logger: any Logging)` [`lily/Core/Push/Implementations/MockPushRegistrar.swift:MockPushRegistrar`].
- `struct NoPushOptIn: PushOptIn`: `offerReminders()` does nothing
  [`lily/Core/Push/Implementations/NoPushOptIn.swift:NoPushOptIn`].

## Invariants

- `PushEventRelay.token` appends a waiter, runs `register()`, and spawns a task that after `timeout` resumes that
  waiter alone with `PushRegistrationError.timedOut` if it is still waiting; `deliver(token:)` resumes every waiter
  with the token as lower-case hex (`%02x` per byte); `fail` resumes every waiter with `.refused(localizedDescription)`
  [`PushEventRelay.swift:PushEventRelay.token(timeout:register:)`, `PushEventRelay.swift:PushEventRelay.deliver(token:)`].
- A tap that arrives before `tapHandler` is set is held as one `pendingTap` and handed over in `tapHandler`'s `didSet`
  [`PushEventRelay.swift:PushEventRelay.tapHandler`, `PushEventRelay.swift:PushEventRelay.notificationTapped(_:)`].
- `SystemPushRegistrar.authorization` maps `UNAuthorizationStatus`: `.notDetermined` to `.notDetermined`, `.denied` to
  `.denied`, `.authorized`, `.provisional` and `.ephemeral` to `.authorized`, `@unknown default` to `.denied`
  [`SystemPushRegistrar.swift:SystemPushRegistrar.authorization()`].
- `SystemPushRegistrar.requestAuthorization` asks for `[.alert, .sound, .badge]`; a thrown error becomes `false`
  with a warning [`SystemPushRegistrar.swift:SystemPushRegistrar.requestAuthorization()`].
- `SystemPushRegistrar.deviceToken` waits `AppConfig.Push.tokenTimeout` through the relay
  [`SystemPushRegistrar.swift:SystemPushRegistrar.deviceToken()`].
- `RemoteDeviceRepository` sends `PUT AppConfig.API.Paths.devices` with the payload and
  `DELETE AppConfig.API.Paths.device(token:)` whose log path substitutes `AppConfig.Push.redactedToken`; both use
  `send(_:failingWith: .unknown)` because a registration failure is never shown
  [`RemoteDeviceRepository.swift:RemoteDeviceRepository.register(_:)`, `RemoteDeviceRepository.swift:RemoteDeviceRepository.unregister(token:)`].
- `MockDeviceRepository` throws `AppError.sessionExpired` for a guest (`identity.currentUserID == nil`), answers the
  token lower-cased, and `removed` is true only when a registration was actually dropped
  [`MockDeviceRepository.swift:MockDeviceRepository.register(_:)`, `MockDeviceRepository.swift:MockDeviceRepository.unregister(token:)`].
- `MockPushRegistrar.requestAuthorization` sets `status = .authorized` and answers `true` without a prompt;
  `deviceToken` answers `AppConfig.Push.mockToken` [`MockPushRegistrar.swift:MockPushRegistrar`].

## Side Effects

- `UNUserNotificationCenter.current().notificationSettings()` and `requestAuthorization(options:)`;
  `UIApplication.shared.registerForRemoteNotifications()` [`SystemPushRegistrar.swift:SystemPushRegistrar`].
- Network through `APIClient`: `PUT` devices, `DELETE` device by token [`RemoteDeviceRepository.swift:RemoteDeviceRepository`].
- One `Task` per token wait for the timeout [`PushEventRelay.swift:PushEventRelay.token(timeout:register:)`].
- Logging under `.push`: info "Mock device registered (<environment>)", "Mock device unregistered", "Mock notification
  permission granted"; warning "Notification permission request failed"
  [`MockDeviceRepository.swift`, `MockPushRegistrar.swift`, `SystemPushRegistrar.swift`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Push`)
