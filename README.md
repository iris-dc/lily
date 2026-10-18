# iskra

A meetup-style iOS app for sport events: find an event near you, join it in a tap, run a group with its own chat, enter
or set up a tournament. iOS 26+, SwiftUI, Liquid Glass, dark. The code name is **lily**: the Xcode project, scheme,
module and bundle id (`iris.lily`) keep it; the home screen says iskra.

## What it does

- **Explore**: upcoming events near you, as a list or a map, filtered by sport, distance, price, level and date, with
  the public groups to discover above them.
- **Events**: create one from the "+" (sport, time, place on a map, how many players, optional price and level), join
  or leave, edit your own. Signed-in users see who is in.
- **Groups and chat** (debug builds): public or invite-only groups for a sport or a place, each with a chat room, a
  roster with roles, direct invites, and events hosted inside the group.
- **Tournaments** (debug builds): single elimination or round robin, players or teams, self-reported results that the
  other side confirms, schedules and reminders.
- **People**: profiles, direct conversations, an inbox for invites and reminders, push notifications once the Apple
  Developer account exists.
- **Seven languages** (en, ru, es, fr, uk, pl, pt), prices in your currency, iPhone and iPad layouts.

Release builds ship Explore, events, people's profiles and the Profile tab; groups, chat (with conversations and the
inbox) and tournaments are behind debug-only feature flags for now.

## How it fits together

```
 ┌───────────────────────────┐          ┌────────────────────────────┐
 │  iskra  (this repository) │  tokens  │  Amazon Cognito            │
 │  SwiftUI, iOS 26          │◀────────▶│  user pool "lily-users"    │
 │  Home · Explore · Chats · │          │  email + password          │
 │  Profile                  │          └────────────────────────────┘
 └─────────────┬─────────────┘
               │  HTTPS, Bearer access token
               ▼
 ┌───────────────────────────┐     ┌──────────┐     ┌─────────────────┐
 │  Laurel  (iris-dc/laurel) │────▶│ DynamoDB │     │ S3 attachments  │◀─ ─ the app uploads and
 │  Spring Boot on Fargate   │     └──────────┘     └─────────────────┘     downloads straight to S3
 │  https://api.iskra.red    │────▶ presigned S3 URLs · AppSync Events (backend side so far) · APNs · SNS
 └───────────────────────────┘
       infrastructure as CDK:  rose  (iris-dc/rose, eu-central-1)
```

The app keeps no credentials of its own: Cognito signs people in, the backend validates the token and reads the user
id from it. Guests can browse events without signing in. The app keeps what it has loaded in memory and asks the
backend again only when it is stale or something changed, because the backend runs on a tight budget; pictures and
files are cached on disk.

## Status

Early days. Sign-in, events, groups, chat, tournaments, the inbox, languages and the iPad layouts work end to end
against the live backend; groups, chat and tournaments are behind feature flags in debug builds. Live message
delivery over AppSync Events is not wired in the app yet: the backend publishes, the app catches up over REST when a
room opens or comes back to the foreground. Push reminders are built on every side but cannot deliver until the
Apple Developer Program account exists (the steps are in `docs/notes/inbox-people-and-push.md`).

## Run it

Requirements: Xcode 26.5 or newer with an iOS 26.5 simulator (and an iPad simulator for the iPad tests). No AWS
credentials are needed to run or test; signing in for real needs a network.

Open `lily.xcodeproj`, pick an iPhone simulator and run the `lily` scheme. From the terminal:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # only if xcode-select points at the Command Line Tools
xcodebuild -scheme lily -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation build
```

Out of the box a simulator run looks for the backend at `http://localhost:8080` and shows "You're offline" without
one. Either start Laurel on your Mac with its `local` profile (how: `docs/notes/auth-and-backend.md`, Backend; the
same note covers a physical iPhone), or add `-mock-events -mock-auth` under Product > Scheme > Edit Scheme > Run >
Arguments to run on fixtures. The shared scheme is gitignored, so your own copy may already carry `-api-base-url`.

Useful launch arguments (debug builds only): `-mock-events` and `-mock-auth` run the app on in-memory fixtures with
no backend; `-start-as-guest` skips the landing; `-app-language ru` shows a language; `-api-base-url
http://<mac-name>.local:8080` points a phone at a Laurel running on your Mac. A debug build on the simulator talks to
`http://localhost:8080`; a debug build on a phone and every release build talk to `https://api.iskra.red`.

## Test it

```sh
./scripts/ci.sh unit      # unit tests, seconds
./scripts/ci.sh ui        # UI tests on an iPhone simulator, about half an hour
./scripts/ci.sh ui-ipad   # the iPad layout tests
./scripts/ci.sh all       # everything CI runs: lint, build, unit, ui, ui-ipad
```

Lint is SwiftLint in strict mode (`brew install swiftlint`) plus a check that every line of copy has a translation.
GitHub Actions runs the same script on every push and pull request to `main`. Logs and `.xcresult` bundles land in
`build/results/`.

## Layout

```
lily/           the app: App (entry, composition root), Config (constants, copy, tokens), Core (networking,
                auth, realtime, localisation, UI components), Features (Landing, SignIn, Shell, Events, Groups,
                Chat, Inbox, People, Tournaments, Profile, Feedback, Moderation)
lilyTests/      unit tests (Swift Testing) with fakes for every interface
lilyUITests/    end-to-end tests against the real app in a simulator
scripts/        ci.sh (lint, build, tests), the localisation check, the app-icon renderer
docs/notes/     engineering notes by area, dated
```

`AGENTS.md` holds the engineering rules (for people and coding agents); `docs/notes/` the detailed, dated notes per
area; `docs/notes/folder-layout.md` the full tree.

## Deployment

The backend and its AWS resources are deployed from the `iris-dc/rose` CDK repository; the app is built and signed
from Xcode. Details, including the Cognito pool and the first-time setup, are in `docs/notes/auth-and-backend.md`.
