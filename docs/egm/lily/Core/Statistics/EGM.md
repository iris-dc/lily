# Statistics

Source: `lily/Core/Statistics/`

## Overview

Usage statistics the backend cannot see for itself: which events, groups, tournaments and chats a signed-in user
viewed, which filter shapes and presentations they used, and whether a group search had a query and how many results
it got. Interactions carry ids, types and flags only, never a coordinate, an amount, a date range or free text; a guest
is never recorded. They are buffered on the device and posted to Laurel in batches (`POST AppConfig.API.Paths.interactions`),
flushed before a sign-out while the Bearer is still sent, and dropped if the session has already ended. The directory
holds no source files of its own.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `InteractionRecorder` (`record(_:)`, `flush()`); recording
  never fails or blocks, a failed send is a log line.
- Models: [./Models/EGM.md](./Models/EGM.md) - `InteractionKind` (seven snake_case wire names), `Interaction` and its
  factories, `FilterSummary` (the shape of a filter without its values), `InteractionBatch`, `InteractionReceipt`.
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteInteractionRecorder` (buffer,
  batch-size and timer flushes, per-user entries, sign-out flush under a deadline) and `NoOpInteractionRecorder` for
  mock runs, previews and UI tests.
