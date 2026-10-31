# Foundation

Source: `lily/Core/Foundation/`

## Overview

How every typed field is read: two `nonisolated` extensions, on `String` and on `String?`, that trim surrounding
whitespace and newlines and collapse blank input to `nil`. One file, Foundation only.

## Interface

- `String.trimmed: String` (`lily/Core/Foundation/String+Trimming.swift:String.trimmed`): the receiver with leading and
  trailing `.whitespacesAndNewlines` removed.
- `String.nonBlankTrimmed: String?` (`lily/Core/Foundation/String+Trimming.swift:String.nonBlankTrimmed`): `trimmed`, or
  `nil` when that is empty.
- `String?.trimmed: String` (`lily/Core/Foundation/String+Trimming.swift:String?.trimmed`): `self?.trimmed ?? ""`.
- `String?.nonBlankTrimmed: String?` (`lily/Core/Foundation/String+Trimming.swift:String?.nonBlankTrimmed`): `self?.nonBlankTrimmed`.

## Invariants

- Only `CharacterSet.whitespacesAndNewlines` is trimmed, through `trimmingCharacters(in:)`; interior whitespace is kept
  (`String+Trimming.swift:String.trimmed`).
- A string is blank when `trimmed.isEmpty`; `nonBlankTrimmed` is `nil` exactly for blank or `nil` input and otherwise
  never empty (`String+Trimming.swift:String.nonBlankTrimmed`, `String?.nonBlankTrimmed`).
- `trimmed` on an optional is never `nil`: `nil` reads as the empty string (`String+Trimming.swift:String?.trimmed`).
- Both extensions are `nonisolated extension`s, so none of the four members is main-actor isolated under the target's
  default isolation (`String+Trimming.swift`).

## Side Effects

- None.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Foundation`).
