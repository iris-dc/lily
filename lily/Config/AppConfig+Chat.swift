import Foundation

nonisolated extension AppConfig {
    /// Chat: message limits, paging and the in-memory room cache.
    ///
    /// Resume budget: a naive foreground would fetch every room, `Groups.maxMemberships` (50) requests against a
    /// per-user burst of 40; the resume protocol subscribes first and catches up only the rooms whose epoch or newest
    /// message moved, `maxConcurrentCatchUps` at a time, and stays under five requests.
    enum Chat {
        static let messageMaxLength = 2000
        /// The composer shows the remaining count from here.
        static let counterThreshold = 1800
        static let historyPageSize = 50
        static let catchUpPageSize = 200
        static let maxCatchUpPages = 3
        static let maxConcurrentCatchUps = 3
        /// Newest messages kept per room in memory.
        static let roomCacheLimit = 300
        /// One sender's messages within this window are drawn as one run.
        static let groupingWindow: TimeInterval = 300
        static let readMarkFlushInterval: TimeInterval = 60
        static let mockEchoDelay: Duration = .milliseconds(200)
        static let mockAutoReplyDelay: Duration = .seconds(1.5)
        static let maxLinksPerMessage = 1
        /// How long the composer stays closed after a 429 that named no `Retry-After`.
        static let rateLimitCooldownFallback: TimeInterval = 10
        /// Rows of the mock chat: this many text messages per joined group, plus one system row.
        static let mockMessagesPerRoom = 12
        /// Rows per mock room under `-mock-chat-replies`: deep enough to page and to scroll for dropped frames.
        static let mockLongRoomMessages = 300
        /// A mock send whose text starts with this fails with a lost connection, so the failed bubble can be tried by hand.
        static let mockFailingPrefix = "!fail"
        /// How often the composer's cooldown caption counts down.
        static let cooldownTick: Duration = .seconds(1)
        /// A reply quotes this much of the original's text (UTF-16 units, cut at a character); Laurel's
        /// `chat.reply-excerpt-length` says the same, so the preview matches what the backend stores.
        static let replyExcerptLength = 120
        /// How many older pages a tap on a quote may load to bring the original on screen.
        static let maxReplyLookupPages = 3
    }
}

nonisolated extension AppConfig.API.Paths {
    static func messages(id: String) -> String {
        "\(group(id: id))/messages"
    }

    static func message(id: String, messageID: String) -> String {
        "\(messages(id: id))/\(messageID)"
    }

    static func read(id: String) -> String {
        "\(group(id: id))/read"
    }
}

nonisolated extension AppConfig.API.Query {
    static let before = "before"
    static let after = "after"
}

nonisolated extension AppConfig.API.Headers {
    static let retryAfter = "Retry-After"
}

nonisolated extension AppConfig.LaunchArguments {
    /// Makes the mock chat answer every sent message after `Chat.mockAutoReplyDelay`; never passed by the UI tests.
    static let mockChatReplies = "-mock-chat-replies"
}
