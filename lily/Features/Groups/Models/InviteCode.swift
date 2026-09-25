import Foundation

/// A valid invite code in its canonical form: 12 symbols of Crockford base32. Input is normalised first (spaces and
/// dashes dropped, upper-cased, the look-alikes `I`/`L` read as `1` and `O` as `0`), as the backend does it, so a code
/// typed from a screenshot still works. It travels only in request bodies and must never reach a log line or a URL path.
nonisolated struct InviteCode: Hashable, Identifiable, Sendable {
    let value: String

    var id: String { value }

    /// `nil` unless `raw` normalises to a valid code.
    init?(_ raw: String) {
        let normalized = Self.normalize(raw)
        guard Self.isValid(normalized) else { return nil }
        value = normalized
    }

    /// Shown grouped in fours: `KRZB-7K3M-QX9P`.
    var formatted: String { Self.grouped(value) }

    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().compactMap(Self.normalizedSymbol))
    }

    static func isValid(_ normalized: String) -> Bool {
        normalized.range(of: AppConfig.Groups.inviteCodePattern, options: .regularExpression) != nil
    }

    /// Any run of symbols in groups of `AppConfig.Groups.inviteCodeGroupSize`, for the display of a code and the
    /// live formatting of one being typed.
    static func grouped(_ symbols: String) -> String {
        let size = AppConfig.Groups.inviteCodeGroupSize
        let characters = Array(symbols)
        return stride(from: 0, to: characters.count, by: size)
            .map { String(characters[$0..<min($0 + size, characters.count)]) }
            .joined(separator: "-")
    }

    private static let separators: Set<Character> = ["-", " "]
    private static let lookAlikes: [Character: Character] = ["I": "1", "L": "1", "O": "0"]

    private static func normalizedSymbol(_ character: Character) -> Character? {
        if separators.contains(character) { return nil }
        return lookAlikes[character] ?? character
    }
}

/// Body of `POST /api/invites/preview` and `POST /api/invites/redeem`: the code, in the body and nowhere else.
nonisolated struct InviteCodePayload: Encodable, Equatable, Sendable {
    let code: String

    init(_ code: InviteCode) {
        self.code = code.value
    }
}
