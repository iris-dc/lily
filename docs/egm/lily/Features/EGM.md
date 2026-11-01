# Features

Source: `lily/Features/`

## Overview

The twelve user-facing features of iskra, one folder each, every folder split by layer
(`Models`, `Interfaces`, `Implementations`, `ViewModels`, `Views`, and where needed `State` and `Services`).
This folder holds no source files of its own. Within a feature, data flows Views -> ViewModels -> Interfaces ->
Implementations -> Laurel, with Models shared by every layer; callers depend on the protocols in `Interfaces`, and
the concrete `Remote*` and `Mock*` types are wired only in `lily/App/AppDependencies` (contract:
[`../App/EGM.md`](../App/EGM.md)). The shared machinery the features build on (networking, auth, realtime, changes
and freshness, UI components) lives in `lily/Core` ([`../Core/EGM.md`](../Core/EGM.md)); copy, limits, tokens and
identifiers in `lily/Config` ([`../Config/EGM.md`](../Config/EGM.md)).

Three features are behind `AppConfig.FeatureFlags` (on in debug and Staging, off in Release): Groups, Chat (with
conversations and the inbox) and Tournaments. The flags are read by the callers that show or route to a gated
feature (Shell, Events, the Landing intro slides, `ShellCommands` and `AppNavigation` outside this folder); inside the
gated features themselves they are read by Groups (`GroupDetailSection`, `GroupDetailViewModel`, `GroupDetailView`,
`GroupDetailMenu`, for the chat and tournaments flags) and by `TournamentDetailViewModel` (the chat flag). Every
feature runs without a backend behind its mocks, and every feature has a unit-test folder of the same name under
`lilyTests/`; `./scripts/ci.sh unit` runs them all.

## Subdirectories & Boundaries

- Landing: [`./Landing/EGM.md`](./Landing/EGM.md) - the first screen for a signed-out visitor: a vertical paging intro
  of framed miniature screens over the aurora, with "Explore events" (guest) and "Sign in" pinned under every slide.
- SignIn: [`./SignIn/EGM.md`](./SignIn/EGM.md) - the sign-in sheet and the email + password form; every credential
  call goes through `SessionController` (`lily/Core/Auth`), validation through `CredentialsValidator`.
- Shell: [`./Shell/EGM.md`](./Shell/EGM.md) - the `TabView` of Home, Explore, Chats (flag-gated) and Profile, the Home
  root and overview, and the two app-lifetime services behind them: `ShellLists` (owns the Home and Explore list view
  models) and `ShellSync` (the ordered per-user sync chain). The screens inside the tabs belong to other features.
- Events: [`./Events/EGM.md`](./Events/EGM.md) - finding sport events near the user, joining and leaving them, creating
  and editing one's own, over `/api/events`; `EventListViewModel` owns a list and its freshness, `EventDetailViewModel`
  the join and leave rules.
- Groups: [`./Groups/EGM.md`](./Groups/EGM.md) - communities a user founds, discovers, joins and runs, plus the two
  other things the backend keeps as groups of another kind, direct conversations (`direct`) and tournament rooms
  (`tournament`); `MyGroupsStore` is the one source of the caller's groups; `GroupErrorReporter` in its `Services` is
  the error path Chat and Tournaments reuse.
- Chat: [`./Chat/EGM.md`](./Chat/EGM.md) - the Chats tab and one open room: transcript, composer, replies, polls, pins,
  attachments and the full-screen viewer; the room cache (`ChatHistoryCache`) is the truth the realtime controller and
  `ChatViewModel` both write.
- Inbox: [`./Inbox/EGM.md`](./Inbox/EGM.md) - the iskra conversation pinned on the Chats tab with group and tournament
  invites and game and match reminders, from `/api/me/inbox` into `InboxStore`, the one source, cleared on sign-out.
- People: [`./People/EGM.md`](./People/EGM.md) - every person named in the app opens a profile with a Message button
  and the groups in common; Message opens a direct conversation, a two-member group of kind `direct` derived once per
  pair.
- Tournaments: [`./Tournaments/EGM.md`](./Tournaments/EGM.md) - organiser-run single-elimination or round-robin
  competitions with entries and teams, a room of their own, brackets or standings, player-reported results and
  organiser-run disputes, walkovers and scheduling; the repositories send exactly once, the `TRY_AGAIN` repeat lives in
  the view models' `WriteGate` and `CreateFlow`.
- Profile: [`./Profile/EGM.md`](./Profile/EGM.md) - the Profile tab and the caller's backend profile: the name other
  players see (chosen on a card and sheet; the backend's "Player" until the user picks one) or the guest prompt,
  language and currency settings, the contact card and Sign out; `ProfileStore` is the one source of that profile over
  `ProfileRepository` (`GET` and `PUT /api/profile`).
- Feedback: [`./Feedback/EGM.md`](./Feedback/EGM.md) - the contact form on Profile: a question, feedback or bug report
  posted once to `POST /api/feedback`.
- Moderation: [`./Moderation/EGM.md`](./Moderation/EGM.md) - the terms-acceptance gate: a sheet presented while a
  signed-in caller owes the current terms, closed only by a recorded acceptance or by signing out; the acceptance
  write lives in `MeStore` (Groups `State`), the legal URLs in `AppConfig.Moderation`.
