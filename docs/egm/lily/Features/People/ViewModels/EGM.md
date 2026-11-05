# People ViewModels

Source: `lily/Features/People/ViewModels/`

## Overview

`UserProfileViewModel` is the model of another person's profile screen: it loads a `UserProfile` through
`UserRepository`, exposes a three-case `State`, and offers one write, `message()`, which starts (or answers again) the
direct conversation with the person, puts it into Mine and hands the conversation to the view through
`openedConversation`, which pushes its chat on the profile's own stack, so Back returns to the profile. Failures go through a `WriteGate` and the
shared `GroupErrorReporter` under the `.groups` log category. The screen is in [Views](../Views/EGM.md).

## Interface

- `@Observable final class UserProfileViewModel` `[lily/Features/People/ViewModels/UserProfileViewModel.swift:UserProfileViewModel]`;
  `init(destination: UserProfileDestination, repository: any UserRepository, identity: any IdentityProvider, myGroups: MyGroupsStore, reporter: GroupErrorReporter, logger: any Logging, tryAgainDelay: Duration = AppConfig.API.tryAgainDelay)`.
- `enum State: Equatable { case loading; case loaded(UserProfile); case failed }`
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:UserProfileViewModel.State]`.
- `destination: UserProfileDestination`; read-only `state` (starts `.loading`) and `isStartingConversation`;
  `var openedConversation: SportGroup?` (set by a successful `message()`, cleared by SwiftUI when the reader pops the
  chat; the view binds it to a `navigationDestination(item:)`); `userID`
  (`destination.userId`), `displayName` (`profile?.displayName ?? destination.displayName`), `profile: UserProfile?`
  (the payload of `.loaded`), `isSelf` (`identity.currentUserID == userID`), `canMessage`
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:UserProfileViewModel]`.
- `func load() async`, `func message() async`; private `gate: WriteGate`, `hasLoggedOpen`, `logOpenOnce()`.

## Invariants

- Message is offered only while `AppConfig.FeatureFlags.chat` is on (without chat there is no conversation to open;
  before 2026-11-05 the flag-off path pushed the direct group on Home, which rendered the same profile again), a user is
  signed in, the profile is not the caller's own and `destination.context == .standalone` (from a chat the conversation
  is one Back away)
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:canMessage]`,
  `[lily/Features/People/Models/UserProfileDestination.swift:UserProfileDestination]`.
- `message()` is single-flight: `guard canMessage, !isStartingConversation`, the flag set and reset with `defer`
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:message]`.
- Order inside the gate: `repository.startConversation(with:)`, then `myGroups.add(conversation)`, then the log line,
  then `openedConversation = conversation`, so the conversation is in Mine (and on the Chats tab) before its chat opens
  in place `[lily/Features/People/ViewModels/UserProfileViewModel.swift:message]`.
- `load()` logs the open once per instance however often the view's `.task` restarts, sets `.loading` only when no
  profile is held, and on a failure keeps a loaded profile on screen (`.failed` only when `profile == nil`); a
  cancellation is silent `[lily/Features/People/ViewModels/UserProfileViewModel.swift:load]`,
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:logOpenOnce]`.
- The `WriteGate` is built with category `.groups`, `tryAgainDelay` (400 ms by default) and
  `report: { reporter.report($0) }`, `isExpected` left at its default, so every failed write logs at error; the gate
  repeats one `TRY_AGAIN` through `LostRace.attemptTwice`, answers `false` silently on cancellation, and the Bool is
  discarded `[lily/Features/People/ViewModels/UserProfileViewModel.swift:init]`,
  `[lily/Core/Networking/WriteGate.swift:WriteGate.run]`, `[lily/Config/AppConfig.swift:AppConfig.API.tryAgainDelay]`.
- `UserProfile.bio`, `sharedGroups`, `sharedEvents` and `sharedTournaments` pass through untouched: no filtering or
  sorting here
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:UserProfileViewModel]`.
- Main-actor isolated by the target's default.

## Side Effects

- `repository.profile(userID:)` on every `load()`; `repository.startConversation(with:)` inside
  `gate.run("Starting a conversation with <id>")` `[lily/Features/People/ViewModels/UserProfileViewModel.swift:load]`,
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:message]`.
- `myGroups.add(conversation)`: `MyGroupsStore.add` removes a same-id entry, inserts per `SportGroup.mineOrder` and
  records a change `[lily/Features/People/ViewModels/UserProfileViewModel.swift:message]`,
  `[lily/Features/Groups/State/MyGroupsStore.swift:add]`.
- `reporter.report(error)` on a failed load and, through the gate, on a failed write; `GroupErrorReporter.report`
  wraps to `AppError`, calls `errorCenter.report` and `onTermsRequired()` for `.termsRequired`
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:load]`,
  `[lily/Features/Groups/Services/GroupErrorReporter.swift:report]`.
- Logging under `.groups`: info "Profile <id> opened" once, info "Conversation <id> started with <id>", error
  "Loading profile <id> failed" `[lily/Features/People/ViewModels/UserProfileViewModel.swift:logOpenOnce]`,
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:message]`,
  `[lily/Features/People/ViewModels/UserProfileViewModel.swift:load]`.
- No `Task {}` spawns, no `.errorPopup` mounts, no direct `ErrorCenter` calls.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People/UserProfileViewModelTests.swift`).
