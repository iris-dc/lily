# Statistics Interfaces

Source: `lily/Core/Statistics/Interfaces/`

## Overview

The one seam of usage statistics: where a screen reports an interaction. View models depend on `InteractionRecorder`
only; `RemoteInteractionRecorder` and `NoOpInteractionRecorder` (`../Implementations/EGM.md`) conform. The protocol
carries no isolation attribute, so it is main-actor under the app target's default.

## Interface

- `protocol InteractionRecorder`: `func record(_ interaction: Interaction)`; `func flush() async` (sends whatever is
  buffered now, for the app going to the background)
  [`lily/Core/Statistics/Interfaces/InteractionRecorder.swift:InteractionRecorder`].

## Invariants

- Documented contract: recording never fails and never blocks the caller; a failed send is a log line, never a popup
  [`lily/Core/Statistics/Interfaces/InteractionRecorder.swift:InteractionRecorder`].

## Side Effects

- None (protocol declaration only).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Statistics`)
