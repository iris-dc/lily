# System Interfaces

Source: `lily/Core/System/Interfaces/`

## Overview

The seam over the system clipboard, so a view model that offers "Copy" is testable without `UIPasteboard`.
`SystemPasteboard` (`../Implementations/EGM.md`) is the conformer.

## Interface

- `protocol Pasteboard` (main-actor under the app target's default): `func copy(_ text: String)`
  [`lily/Core/System/Interfaces/Pasteboard.swift:Pasteboard`].

## Invariants

- None beyond the signature.

## Side Effects

- None (protocol declaration only).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/System`)
