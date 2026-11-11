# Create Interfaces

Source: `lily/Features/Create/Interfaces/`

## Overview

One protocol: `CreationWizardControlling`, the kind-agnostic seam between the wizard's pages and the shell model.
The concrete `CreationWizardModel` is generic over the three kind view-model types; a step page is generic over its
own kind's draft-editing view model alone, so it reads the wizard through this existential instead of carrying the
other kinds' parameters. Observation rides the conforming `@Observable` class — views reading through the
existential still track, because tracking is the concrete class's accessors, not the static type.

## Interface

- `CreationWizardControlling` (`lily/Features/Create/Interfaces/CreationWizardControlling.swift`):
  `AnyObject, Observable`. Read: `opening: CreationWizardPolicy.Opening`, `path: [CreationStep]` (read-only here;
  the shell alone binds it), `steps: [CreationStep]`, `isSubmitting`, `canSubmit`. Act: `enter(_ kind:)`,
  `advance(from:)`, `pop(to:)`, `allowsNext(from:) -> Bool`, `blockingMessage(on:) -> String?`,
  `blockedEarlierStep(before:) -> CreationStep?`, `submit() async`.

## Invariants

- `CreationWizardModel` is the one conformer (`lily/Features/Create/State/CreationWizardModel+Gating.swift`); the
  protocol never exposes a kind's view model or draft — pages bind those through their own generic parameter — and
  never a typed issue: the hint copy crosses as `blockingMessage(on:)`, already localized by the kind's branding.
- No auth, storage or network: the protocol is presentation state and actions only.

## Side Effects

- None; a protocol. Conformer side effects are the State contract's ([`../State/EGM.md`](../State/EGM.md)).

## Verification

- Run: `./scripts/ci.sh build` (zero `/lily/` warnings); the conformer's behavior is pinned by
  `lilyTests/Create/CreationWizardModelTests.swift` and `CreationWizardModelKindsTests.swift`.
