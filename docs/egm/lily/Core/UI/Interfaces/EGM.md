# Interfaces

Source: `lily/Core/UI/Interfaces/`

## Overview

One protocol, `DraftSubmitting`: what the shared `DraftSheet` (see [Components](../Components/EGM.md)) needs from a
create or edit view model: the draft's validation issues for the hints under each section, the request's state for the
submit bar, and the two calls the sheet makes on the model's behalf (`prepare()` when it appears, `submit()` on the
button). The conformers live in the features (`EventDraftEditing`, `GroupDraftEditing`, `TournamentDraftEditing`
refine it in their `Interfaces/` folders); this folder holds only the contract.

## Interface

- `protocol DraftSubmitting: AnyObject, Observable` [`lily/Core/UI/Interfaces/DraftSubmitting.swift:DraftSubmitting`]:
  main-actor isolated (the app target's default isolation; it is not `nonisolated`). Requirements:
  - `associatedtype Issue: Equatable`: the conformer's validation-issue type.
  - `var issues: [Issue] { get }`: the draft's current issues, shown as hints.
  - `var isSubmitting: Bool { get }`: a request is in flight.
  - `var canSubmit: Bool { get }`: whether the bar's submit action is enabled.
  - `var isDone: Bool { get }`: the backend answered; the sheet closes.
  - `func prepare() async`: runs once when the sheet appears, before the user types (a create proposes the device's
    position and reads the groups the caller may host in; an edit has nothing to fetch).
  - `func submit() async`: performs the create or edit request.
- `extension DraftSubmitting` [`lily/Core/UI/Interfaces/DraftSubmitting.swift:DraftSubmitting.prepare`]:
  `func prepare() async {}`, the empty default, so an edit model implements nothing.
- `func issue(for candidates: Issue...) -> Issue?` [`lily/Core/UI/Interfaces/DraftSubmitting.swift:DraftSubmitting.issue(for:)`]:
  `issues.first(of: candidates)`, the first of the candidates the draft has, for the hint under the section they
  concern (`Collection.first(of:)` is defined in `lily/Core/Validation`).

## Invariants

- `prepare()` is declared both as a protocol requirement and as an extension default, so a conformer's own `prepare()`
  is dispatched dynamically; as an extension method alone, `DraftSheet`'s call on `Model` would bind statically to the
  empty default and the create model's position proposal would never run
  [`lily/Core/UI/Interfaces/DraftSubmitting.swift:DraftSubmitting.prepare`].
- Conformers are classes (`AnyObject`) and `Observable`, so `DraftSheet` holds one by reference and SwiftUI tracks
  `issues`, `isSubmitting`, `canSubmit` and `isDone`; `Issue: Equatable` is what `issue(for:)` matches on
  [`lily/Core/UI/Interfaces/DraftSubmitting.swift:DraftSubmitting`].
- The protocol itself fetches nothing and holds no state; what `prepare()` and `submit()` do is the conformer's,
  documented in the feature contracts.

## Side Effects

- None in this folder: `prepare()` and `submit()` are the conformers' effects.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root). The protocol has no suite of its own; its conformers are
  covered by the feature view-model suites under `lilyTests/Events`, `lilyTests/Groups` and `lilyTests/Tournaments`,
  and the rendered sheet is checked by screenshot on a simulator per `AGENTS.md`.
