# Validation

Source: `lily/Core/Validation/`

## Overview

Client-side checks that mirror what the backend refuses, so a draft that passes here is never a 400 there: the email and
password rules used before credentials leave the device, the UTF-16 length the backend's `@Size` counts, the code-point
length Laurel's display-name rule counts, and a small collection helper that names the first wrong field of a form
section. Everything is `nonisolated` and pure.

## Interface

- `nonisolated enum CredentialsValidator`: `static func isValidEmail(_ email: String) -> Bool`,
  `static func isValidPassword(_ password: String) -> Bool`
  [`lily/Core/Validation/CredentialsValidator.swift:CredentialsValidator`].
- `nonisolated extension String`: `var wireLength: Int`, `func prefix(wireLength maxLength: Int) -> String`
  [`lily/Core/Validation/String+WireLength.swift:String.wireLength`, `String+WireLength.swift:String.prefix(wireLength:)`].
- `nonisolated extension String?`: `var wireLength: Int` [`lily/Core/Validation/String+WireLength.swift:Optional<String>.wireLength`].
- `nonisolated extension String`: `var codePointCount: Int`, `func prefix(codePoints maxLength: Int) -> String`
  [`lily/Core/Validation/String+CodePoints.swift:String.codePointCount`, `String+CodePoints.swift:String.prefix(codePoints:)`].
- `nonisolated extension Collection where Element: Equatable`: `func first(of candidates: [Element]) -> Element?`,
  `func first(of candidates: Element...) -> Element?` [`lily/Core/Validation/Collection+FirstOf.swift:Collection.first(of:)`].

## Invariants

- `isValidEmail` trims the input (`String.trimmed`, `lily/Core/Foundation`) and then requires: no whitespace or
  newline anywhere; exactly one `@`, not at the start; a local part whose `wireLength` is at most
  `AppConfig.Auth.emailLocalPartMaxLength`; a domain containing a `.` that is neither its first nor its last
  character. This mirrors Laurel's `@Email`; Cognito stays the authority for sign-in
  [`CredentialsValidator.swift:CredentialsValidator.isValidEmail(_:)`].
- `isValidPassword` is `password.count >= AppConfig.Auth.minimumPasswordLength`
  [`CredentialsValidator.swift:CredentialsValidator.isValidPassword(_:)`].
- `wireLength` is `utf16.count`, the unit Java's `String.length()` and Bean Validation's `@Size` count, so an emoji
  counts two here as it does there; `nil` counts 0
  [`String+WireLength.swift:String.wireLength`, `String+WireLength.swift:Optional<String>.wireLength`].
- `prefix(wireLength:)` keeps the longest prefix of whole `Character`s whose UTF-16 total stays within the cap, so a
  cut never splits an emoji and never exceeds the backend's limit [`String+WireLength.swift:String.prefix(wireLength:)`].
- `codePointCount` is `unicodeScalars.count`, the unit Laurel's `codePointCount` uses for a display name, so an emoji
  is one here where `wireLength` counts two; `prefix(codePoints:)` keeps the first `maxLength` scalars, never cutting
  inside one [`String+CodePoints.swift:String.codePointCount`, `String+CodePoints.swift:String.prefix(codePoints:)`].
- `first(of:)` is ordered by the candidates, not by the collection: it answers the first candidate the collection
  contains [`Collection+FirstOf.swift:Collection.first(of:)`].

## Side Effects

- None (pure functions).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Validation`)
