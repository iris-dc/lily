# Logging

Source: `lily/Core/Logging/`

## Overview

The app's one log facade, split into the protocol and enums every call site depends on (`Interfaces/`) and the `os`
conformer the composition root installs (`Implementations/`). No source files live directly in this directory.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `Logging` (one `log(_:_:_:)` requirement plus `debug`, `info`,
  `warning`, `error` forwarders), `LogCategory` (fifteen areas, `auth` to `currency`) and `LogLevel`.
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `OSLogLogger`, one `os.Logger` per category
  under `AppConfig.Logging.subsystem`, every message `privacy: .public`.
