# System

Source: `lily/Core/System/`

## Overview

Thin wrappers over Foundation and UIKit system services: a seam over the clipboard (`Interfaces/`, `Implementations/`)
and two `nonisolated` extensions used across features, the next full hour of a calendar and a file removal that treats
a missing file as nothing to do.

## Interface

- Children: [Interfaces](./Interfaces/EGM.md) (`Pasteboard`), [Implementations](./Implementations/EGM.md)
  (`SystemPasteboard`).
- `nonisolated extension Calendar { func nextFullHour(after date: Date) -> Date }`
  [`lily/Core/System/Calendar+NextFullHour.swift:Calendar.nextFullHour(after:)`].
- `nonisolated extension FileManager { func removeItemIfPresent(at url: URL) throws }`
  [`lily/Core/System/FileManager+RemoveIfPresent.swift:FileManager.removeItemIfPresent(at:)`].

## Invariants

- `nextFullHour(after:)` takes `dateInterval(of: .hour, for: date)` in the calendar's own zone: a date exactly on the
  hour is returned unchanged (`hour.start == date`), anything past it rounds up to `hour.end`; when no interval can be
  computed the input is returned [`Calendar+NextFullHour.swift:Calendar.nextFullHour(after:)`].
- `removeItemIfPresent(at:)` returns without error when `fileExists(atPath: url.path())` is false; a removal the file
  system refuses still throws [`FileManager+RemoveIfPresent.swift:FileManager.removeItemIfPresent(at:)`].

## Side Effects

- `removeItemIfPresent` deletes the item at `url` from disk [`FileManager+RemoveIfPresent.swift:FileManager.removeItemIfPresent(at:)`].
- `nextFullHour` is pure.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/System`)
