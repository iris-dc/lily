# System Implementations

Source: `lily/Core/System/Implementations/`

## Overview

The UIKit conformer of `Pasteboard` (`../Interfaces/EGM.md`).

## Interface

- `final class SystemPasteboard: Pasteboard` (main-actor; imports UIKit): `func copy(_ text: String)`
  [`lily/Core/System/Implementations/SystemPasteboard.swift:SystemPasteboard`].

## Invariants

- `copy` assigns the text whole to `UIPasteboard.general.string`; nothing is transformed
  [`SystemPasteboard.swift:SystemPasteboard.copy(_:)`].

## Side Effects

- Writes the system-wide general pasteboard [`SystemPasteboard.swift:SystemPasteboard.copy(_:)`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/System`)
