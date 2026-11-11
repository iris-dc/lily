# Features

Source: `lily/Features/`

## Overview

The thirteen user-facing features of iskra, one folder each, every folder split by layer
(`Models`, `Interfaces`, `Implementations`, `ViewModels`, `Views`, and where needed `State` and `Services`).
This folder holds no source files of its own. Within a feature, data flows Views -> ViewModels -> Interfaces ->
Implementations -> Laurel, with Models shared by every layer; callers depend on the protocols in `Interfaces`, and
the concrete `Remote*` and `Mock*` types are wired only in `lily/App/AppDependencies` (contract:
[`../App/EGM.md`](../App/EGM.md)). The shared machinery the features build on (networking, auth, realtime, changes
and freshness, UI components) lives in `lily/Core` ([`../Core/EGM.md`](../Core/EGM.md)); copy, limits, tokens and
identifiers in `lily/Config` ([`../Config/EGM.md`](../Config/EGM.md)).

Three features are behind `AppConfig.FeatureFlags` (on in debug and Staging, off in Release): Groups, Chat (with
conversations and the inbox) and Tournaments. The flags are read by the callers that show or route to a gated
feature (Shell, Events, Create (`CreationWizardPolicy.Flags.current`), the Landing intro slides, `ShellCommands`
and `AppNavigation` outside this folder); inside the
gated features themselves they are read by Groups (`GroupDetailSection`, `GroupDetailViewModel`, `GroupDetailView`,
`GroupDetailMenu`, for the chat and tournaments flags) and by `TournamentDetailViewModel` (the chat flag). Every
feature runs without a backend behind its mocks, and every feature has a unit-test folder of the same name under
`lilyTests/`; `./scripts/ci.sh unit` runs them all.

## Subdirectories & Boundaries

- Landing: [`./Landing/EGM.md`](./Landing/EGM.md) - the first screen for a signed-out visitor: a vertical paging intro
  of framed miniature screens over the aurora, with "Explore events" (guest) and "Sign in" pinned under every slide.
- SignIn: [`./SignIn/EGM.md`](./SignIn/EGM.md) - the sign-in sheet and the email + password form; every credential
  call goes through `SessionController` (`lily/Core/Auth`), validation through `CredentialsValidator`.
- Shell: [`./Shell/EGM.md`](./Shell/EGM.md) - the `TabView` of Home, Explore and Chats (flag-gated) with the profile
  as a sheet behind the corner control on every tab root (the Profile tab removed 2026-11-07), the Home
  root and overview, and the two app-lifetime services behind them: `ShellLists` (owns the Home and Explore list view
  models) and `ShellSync` (the ordered per-user sync chain). The screens inside the tabs belong to other features.
- Events: [`./Events/EGM.md`](./Events/EGM.md) - finding sport events near the user, joining and leaving them, creating
  and editing one's own, over `/api/events`; `EventListViewModel` owns a list and its freshness, `EventDetailViewModel`
  the join and leave rules.
- Create: [`./Create/EGM.md`](./Create/EGM.md) - the paged creation wizard, the one create flow for events,
  groups and tournaments (slice 3 of the creation-wizard plan, 2026-11-11): `CreationKind` and the seed, the
  flags-by-context opening matrix (`CreationWizardPolicy`, pure, no auth input), the per-kind step lists with their
  exhaustive issue partitions and Next gating (`CreationSteps`); the page-facing protocol (`Interfaces/`), the
  wizard shell model (`CreationWizardModel`, `State/`) and the chrome with the per-kind one-idea glass pages
  (`Views/`, `Views/Event|Group|Tournament/`). Every create entry — Explore's "+", the ⌘ shortcuts, a group
  screen's buttons — walks it; the single-page forms stay for edit.
- Groups: [`./Groups/EGM.md`](./Groups/EGM.md) - communities a user founds, discovers, joins and runs, plus the two
  other things the backend keeps as groups of another kind, direct conversations (`direct`) and tournament rooms
  (`tournament`); `MyGroupsStore` is the one source of the caller's groups; every screen reports failures to the shared
  `ErrorCenter` (the `GroupErrorReporter` seam went with the terms gate, 2026-11-08).
- Chat: [`./Chat/EGM.md`](./Chat/EGM.md) - the Chats tab and one open room: transcript, composer, replies, polls, pins,
  attachments and the full-screen viewer; the room cache (`ChatHistoryCache`) is the truth the realtime controller and
  `ChatViewModel` both write.
- Inbox: [`./Inbox/EGM.md`](./Inbox/EGM.md) - the iskra conversation pinned on the Chats tab with group and tournament
  invites and game and match reminders, from `/api/me/inbox` into `InboxStore`, the one source, cleared on sign-out.
- People: [`./People/EGM.md`](./People/EGM.md) - every person named in the app opens a profile with a Message button,
  their bio, and the groups, games and tournaments in common; Message opens a direct conversation, a two-member group of
  kind `direct` derived once per pair.
- Tournaments: [`./Tournaments/EGM.md`](./Tournaments/EGM.md) - organiser-run single-elimination or round-robin
  competitions with entries and teams, a room of their own, brackets or standings, player-reported results and
  organiser-run disputes, walkovers and scheduling; the repositories send exactly once, the `TRY_AGAIN` repeat lives in
  the view models' `WriteGate` and `CreateFlow`.
- Profile: [`./Profile/EGM.md`](./Profile/EGM.md) - the profile sheet (presented from the shell's corner button since
  2026-11-07) and the caller's backend profile: the name other
  players see (chosen on a card and sheet; the backend's "Player" until the user picks one) and the "About you" bio
  (a card and sheet of its own) with a link into `SettingsScreen` (language, currency, the contact card, the legal
  links and Sign out; 2026-11-07), or the guest prompt with the language, currency and contact rows inline;
  `ProfileStore` is the one source of that profile over `ProfileRepository` (`GET` and `PUT /api/profile`).
- Feedback: [`./Feedback/EGM.md`](./Feedback/EGM.md) - the contact form (reached from Settings when signed in, from
  the guest profile root otherwise): a question, feedback or bug report posted once to `POST /api/feedback`.
- Moderation: removed 2026-11-08 (owner decision: the app never prompts to accept terms) — the folder held only
  the terms gate (`TermsSheet`, `TermsViewModel`); reporting and blocking live in Groups, the sign-up agreement
  footnote in SignIn, the legal reading screens in Profile.
