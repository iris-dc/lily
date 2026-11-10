# lily/Features/Create

Source: `lily/Features/Create/`

## Overview

The paged creation wizard of iskra: one flow that replaces the three create form sheets, opening on a kind page
(event, group, tournament) when context offers a real choice and stepping through the chosen kind's fields one page
at a time (the creation-wizard plan in groups-plan, 2026-11-10). `Models/` holds the pure decision types the wizard
and its tests pin — the kind, the entry seed, the flags-by-context opening matrix and the event flow's step list with
its issue partition and Next gating. `State/` holds the wizard shell's observable model (generic over the kind
view-model types, the event one wired in slice 2), `Views/` the chrome — the `NavigationStack` shell, the kind page,
the shared step scaffold with its progress mark, step captions and entrance motion — and `Views/Event/` the event
flow's seven one-idea glass pages (the owner's second design round, 2026-11-10). Slice 2's bridge wires the event
entries: Explore's "+" event item and the ⌘N game intent present the wizard (a full-screen cover on compact, a form
sheet on regular, the model owned above both presenters in Events); the group and tournament entries keep their form
sheets until slice 3. The
three create view models, their drafts, their validation issues and the idempotent submit path are reused unchanged
by design; this folder owns presentation-side decisions only and never reads auth — the guest substitution stays with
`CreateIntentPolicy` in Events (see [`../Events/EGM.md`](../Events/EGM.md)).

## Subdirectories & Boundaries

- Models: [./Models/EGM.md](./Models/EGM.md) - the pure `nonisolated` decision types: `CreationKind` (with its
  mapping from `CreateIntent`), `CreationSeed` (kind plus locked hosting group), `CreationWizardPolicy` (kinds
  offered by the feature flags, kind page shown or skipped, seed normalization, the eligible-groups fact carried on
  the opening; no auth input) and `CreationStep`/`CreationSteps` (the event flow's ordered one-idea pages with the
  hosting-group step skipped when locked, groups off, or none, the exhaustive `EventDraft.Issue`-to-step partition
  and the Next-gating predicate).
- State: [./State/EGM.md](./State/EGM.md) - `CreationWizardModel` and `CreationWizardFactories`: the one-way kind,
  the lazily created kind view model, the entered-steps path, the user-edit dirty rule, the submit lock and the
  wizard's log lines; built only by `AppDependencies.makeCreationWizardModel`
  ([`../../App/EGM.md`](../../App/EGM.md)).
- Views: [./Views/EGM.md](./Views/EGM.md) - `CreationWizardView` (the `NavigationStack` shell, presentation-agnostic),
  `CreationKindPage`, `WizardStepScaffold` and its shared pieces; the event step pages under
  [./Views/Event/EGM.md](./Views/Event/EGM.md).
