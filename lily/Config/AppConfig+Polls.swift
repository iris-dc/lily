import Foundation

nonisolated extension AppConfig.Chat {
    /// Polls, with Laurel's limits (`chat.polls`): the question and each option are trimmed and counted in UTF-16 units.
    enum Polls {
        static let questionMaxLength = 255
        static let optionMaxLength = 100
        static let minOptions = 2
        static let maxOptions = 10
        /// Polls asked for in one refresh, the newest the room holds (`GET /polls?ids=`).
        static let refreshMaxIDs = 50
    }

    enum Pins {
        /// Laurel's `chat.pins.max`: a pin past it answers `TOO_MANY_PINS`.
        static let maxPins = 50
    }
}

nonisolated extension AppConfig.API.Paths {
    static func vote(id: String, messageID: String) -> String {
        "\(message(id: id, messageID: messageID))/vote"
    }

    static func voters(id: String, messageID: String) -> String {
        "\(message(id: id, messageID: messageID))/votes"
    }

    static func polls(id: String) -> String {
        "\(group(id: id))/polls"
    }

    static func pin(id: String, messageID: String) -> String {
        "\(group(id: id))/pins/\(messageID)"
    }
}

nonisolated extension AppConfig.API.Query {
    static let ids = "ids"
}
