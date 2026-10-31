# Logging Implementations

Source: `lily/Core/Logging/Implementations/`

## Overview

`OSLogLogger`, the one concrete `Logging`: it routes each entry to Apple's unified logging through one `os.Logger` per
`LogCategory`, built once at init for a subsystem that defaults to `AppConfig.Logging.subsystem`
(`lily/Config/AppConfig.swift`, the bundle identifier).

## Interface

- `OSLogLogger: Logging` (`lily/Core/Logging/Implementations/OSLogLogger.swift:OSLogLogger`): `final class` (main-actor
  by the target's default); `init(subsystem: String = AppConfig.Logging.subsystem)`;
  `log(_ level: LogLevel, _ category: LogCategory, _ message: String)`.

## Invariants

- Exactly one `os.Logger(subsystem:category:)` per `LogCategory.allCases` entry, the `os` category string being
  `category.rawValue`; the table is a `private let`, so it is immutable after init (`OSLogLogger.swift:init`, `loggers`).
- `log` dispatches one-to-one on `level` to `logger.debug`, `logger.info`, `logger.warning`, `logger.error`; the
  `switch` is exhaustive with no `default`. A category without a logger returns silently, a branch the populated table
  makes unreachable (`OSLogLogger.swift:log`).
- Every message is interpolated with `privacy: .public` at all four levels, so nothing is redacted in the unified log:
  the facade's "ids only, never secrets" rule is what keeps the log safe. The message is passed through unchanged, with
  no prefix, trimming or truncation (`OSLogLogger.swift:log`).

## Side Effects

- Writes an entry to the unified logging system (`os.Logger`) tagged with the subsystem and the category's raw value, at
  the level given (`OSLogLogger.swift:log`). Init creates the fifteen logger handles and emits nothing.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; no dedicated suite, `lilyTests/Support/SpyLogger.swift` stands
  in for `Logging` across the suites that pin log lines).
