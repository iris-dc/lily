@testable import lily

/// Records log lines so tests can assert on key events.
@MainActor
final class SpyLogger: Logging {
    struct Entry {
        let level: LogLevel
        let category: LogCategory
        let message: String
    }

    private(set) var entries: [Entry] = []

    func log(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        entries.append(Entry(level: level, category: category, message: message))
    }

    /// Messages of one category, optionally narrowed to one level.
    func messages(in category: LogCategory, at level: LogLevel? = nil) -> [String] {
        entries.filter { $0.category == category && (level == nil || $0.level == level) }.map(\.message)
    }

    /// The messages of one category (and level) mentioning every part, so a test pins a line's ids and key words rather
    /// than its whole sentence.
    func lines(in category: LogCategory, at level: LogLevel? = nil, mentioning parts: String...) -> [String] {
        messages(in: category, at: level).mentioning(parts)
    }

    func hasLine(in category: LogCategory, at level: LogLevel? = nil, mentioning parts: String...) -> Bool {
        !messages(in: category, at: level).mentioning(parts).isEmpty
    }

    func count(in category: LogCategory, at level: LogLevel? = nil, mentioning parts: String...) -> Int {
        messages(in: category, at: level).mentioning(parts).count
    }
}

extension Array where Element == String {
    /// The lines containing every part, all in the one line; no parts answers every line.
    func mentioning(_ parts: [String]) -> [String] {
        filter { line in parts.allSatisfy { line.contains($0) } }
    }

    /// The variadic form; Swift cannot forward a variadic to another variadic, hence the array overload.
    func mentioning(_ parts: String...) -> [String] {
        mentioning(parts)
    }
}
