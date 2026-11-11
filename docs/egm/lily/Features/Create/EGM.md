# lily/Features/Create

Source: `lily/Features/Create/`

## Overview

The paged creation wizard of iskra: the one creation flow for events, groups and tournaments, opening on a kind page
(glass choice cards) when context offers a real choice and stepping through the chosen kind's fields one idea per
page (the creation-wizard plan in groups-plan, 2026-11-10; the group and tournament flows and the menu's removal are
slice 3, 2026-11-11). `Models/` holds the pure decision types the wizard and its tests pin — the kind, the entry
seed, the flags-by-context opening matrix, the per-kind step lists with their exhaustive issue partitions and Next
gating, and the per-kind issue under one roof (`CreationIssue`). `Interfaces/` holds `CreationWizardControlling`,
what the pages read so each stays generic over its own kind's view model alone. `State/` holds the wizard shell's
observable model (generic over the three kind view-model types; only the composition root names them), `Views/` the
chrome — the `NavigationStack` shell, the kind page, the shared step scaffold with its progress mark, step captions
and entrance motion, and the per-step copy map — and `Views/Event|Group|Tournament` the kinds' one-idea glass pages
(7, 6 and 9). Every create entry walks the wizard: Explore's "+" (a plain button, the menu gone with slice 3), the
⌘N/⌘⇧N/⌘⇧T intents, and a group screen's create-game and create-tournament affordances (seeded with the kind and the
locked group, the kind page skipped). The three create view models, their drafts, their validation issues and the
idempotent submit path are reused unchanged by design; this folder owns presentation-side decisions only and never
reads auth — the guest substitution stays with `CreateIntentPolicy` in Events (see
[`../Events/EGM.md`](../Events/EGM.md)).

## Subdirectories & Boundaries

- Models: [./Models/EGM.md](./Models/EGM.md) - the pure `nonisolated` decision types: `CreationKind` (with its
  mapping from `CreateIntent`), `CreationSeed` (kind plus locked hosting group), `CreationWizardPolicy` (kinds
  offered by the feature flags, kind page shown or skipped, seed normalization, the eligible-groups fact carried on
  the opening; no auth input), `CreationStep`/`CreationSteps` (the per-kind ordered one-idea pages, the exhaustive
  issue-to-step partitions and the Next-gating predicates; `offersGroupChoice` shared by the event and tournament
  walks) and `CreationIssue` (one kind's issue under the wizard's roof).
- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `CreationWizardControlling`, the kind-agnostic seam the
  pages and the step scaffold read; `CreationWizardModel` is its one conformer.
- State: [./State/EGM.md](./State/EGM.md) - `CreationWizardModel` and `CreationWizardFactories`: the one-way kind,
  the lazily created kind view model, the entered-steps path, the user-edit dirty rule over the shared place
  bookkeeping, the submit lock and the wizard's log lines; built only by `AppDependencies.makeCreationWizardModel`
  ([`../../App/EGM.md`](../../App/EGM.md)).
- Views: [./Views/EGM.md](./Views/EGM.md) - `CreationWizardView` (the `NavigationStack` shell, presentation-agnostic),
  `CreationKindPage`, `WizardStepScaffold` with its shared pieces and the per-step copy map (`WizardStepCopy.swift`);
  the step pages under [./Views/Event/EGM.md](./Views/Event/EGM.md), [./Views/Group/EGM.md](./Views/Group/EGM.md)
  and [./Views/Tournament/EGM.md](./Views/Tournament/EGM.md).
