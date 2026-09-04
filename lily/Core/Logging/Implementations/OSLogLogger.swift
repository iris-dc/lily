import Foundation
import os

/// Routes log events to the unified logging system, one `os.Logger` per category.
final class OSLogLogger: Logging {
    private let loggers: [LogCategory: os.Logger]

    init(subsystem: String = AppConfig.Logging.subsystem) {
        var loggers: [LogCategory: os.Logger] = [:]
        for category in [LogCategory.auth, .events, .chat, .network, .cache, .ui] {
            loggers[category] = os.Logger(subsystem: subsystem, category: category.rawValue)
        }
        self.loggers = loggers
    }

    func log(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        guard let logger = loggers[category] else { return }
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }
}
