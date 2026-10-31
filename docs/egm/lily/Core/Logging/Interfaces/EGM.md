# Logging Interfaces

Source: `lily/Core/Logging/Interfaces/`

## Overview

The logging facade every call site depends on: the `LogCategory` and `LogLevel` enums, the `Logging` protocol with its
one `log(_:_:_:)` requirement, and the per-level convenience methods that forward to it. Nothing here names a sink; the
`os` conformer is in `../Implementations/`.

## Interface

- `LogCategory` (`lily/Core/Logging/Interfaces/Logging.swift:LogCategory`): `nonisolated enum: String, CaseIterable,
  Sendable`; cases (raw value equal to the name) `auth`, `events`, `groups`, `chat`, `inbox`, `network`, `cache`, `ui`,
  `location`, `statistics`, `push`, `localization`, `tournaments`, `feedback`, `currency`.
- `LogLevel` (`lily/Core/Logging/Interfaces/Logging.swift:LogLevel`): `nonisolated enum: Sendable`; `debug`, `info`,
  `warning`, `error`.
- `Logging` (`lily/Core/Logging/Interfaces/Logging.swift:Logging`): protocol (main-actor by the target's default) with
  `func log(_ level: LogLevel, _ category: LogCategory, _ message: String)`.
- Extension (`lily/Core/Logging/Interfaces/Logging.swift:Logging.debug`, `info`, `warning`, `error`):
  `debug(_ category: LogCategory, _ message: String)` and the three siblings, each calling `log(<level>, category, message)`.
- Conformer: [Implementations](../Implementations/EGM.md).

## Invariants

- Every convenience method forwards unchanged to `log(_:_:_:)` with the matching `LogLevel`, so a conformer writes only
  `log` and every level routes through it (`Logging.swift:Logging`).
- `LogCategory` and `LogLevel` are `nonisolated` and `Sendable`, so they cross actor boundaries; `LogCategory` is
  `CaseIterable`, which `OSLogLogger` relies on to build one logger per category (`Logging.swift:LogCategory`).
- The protocol's doc states that messages carry ids only, never secrets or personal data; this is a documented contract,
  not enforced in code (`Logging.swift:Logging`).

## Side Effects

- None in this directory.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; no dedicated suite, `lilyTests/Support/SpyLogger.swift` stands
  in for `Logging` across the suites that pin log lines).
