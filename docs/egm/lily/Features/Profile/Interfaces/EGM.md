# Profile Interfaces

Source: `lily/Features/Profile/Interfaces/`

## Overview

The profile boundary towards the backend, and what the two editors' drafts share. Identity stays with Cognito, so
`ProfileRepository` carries only what the backend shows to others: the caller's display name and bio, read and written.
`ProfileFieldDraft` is the shape `ProfileFieldViewModel` ([ViewModels](../ViewModels/EGM.md)) needs of a draft. The
implementations are in [Implementations](../Implementations/EGM.md), the wire types and drafts in
[Models](../Models/EGM.md), the one caller of the repository in [State](../State/EGM.md).

## Interface

- `protocol ProfileRepository` `[lily/Features/Profile/Interfaces/ProfileRepository.swift:ProfileRepository]`
  (main-actor isolated by the target's default): `func profile() async throws -> Profile` (`GET /api/profile`),
  `func updateDisplayName(_ name: String) async throws -> Profile` (`PUT /api/profile`, answering the name as the
  backend stored it: trimmed, cut to its cap) and `func updateBio(_ bio: String) async throws -> Profile`
  (`PUT /api/profile` with the bio alone; a blank clears it; the answer carries it stripped and cut to its cap).
- `nonisolated protocol ProfileFieldDraft: Equatable, Sendable`
  `[lily/Features/Profile/Interfaces/ProfileFieldDraft.swift:ProfileFieldDraft]`: `associatedtype Issue: Equatable`,
  `init(text:)`, `var text: String { get set }`, `trimmedText` (what goes out), `issues: [Issue]`, `isValid`,
  `hint: String?`.

## Invariants

- The backend creates the profile with its default name on first contact, so a read never finds nothing
  `[lily/Features/Profile/Interfaces/ProfileRepository.swift:ProfileRepository]`.
- No guards beyond the declarations: three `async throws` requirements and a value protocol.

## Side Effects

- None: protocol declarations only.

## Verification

- Run: `./scripts/ci.sh unit`
