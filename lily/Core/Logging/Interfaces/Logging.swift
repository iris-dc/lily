import Foundation

nonisolated enum LogCategory: String, Sendable {
    case auth, events, chat, network, cache, ui
}

nonisolated enum LogLevel: Sendable {
    case debug, info, warning, error
}

/// Single logging facade. Call sites never touch the concrete sink.
/// Never pass secrets or PII in `message`.
protocol Logging {
    func log(_ level: LogLevel, _ category: LogCategory, _ message: String)
}

extension Logging {
    func debug(_ category: LogCategory, _ message: String) { log(.debug, category, message) }
    func info(_ category: LogCategory, _ message: String) { log(.info, category, message) }
    func warning(_ category: LogCategory, _ message: String) { log(.warning, category, message) }
    func error(_ category: LogCategory, _ message: String) { log(.error, category, message) }
}
