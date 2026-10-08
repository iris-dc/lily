import Foundation

nonisolated extension AppConfig {
    /// The contact form on Profile. The limits mirror Laurel's `FeedbackRequest`, so a draft that passes here never
    /// earns a 400; the details are cut to `detailMaxLength` before they are sent.
    enum Feedback {
        static let messageMaxLength = 2000
        static let replyEmailMaxLength = 254
        /// The longest `appVersion`, `osVersion` and `device` the backend accepts.
        static let detailMaxLength = 80
        /// The OS the app runs on, as the bug report names it; the device model tells an iPad from an iPhone.
        static let osName = "iOS"
        /// The simulator's model identifier lives in this environment variable; `uname` answers the Mac's architecture there.
        static let simulatorModelKey = "SIMULATOR_MODEL_IDENTIFIER"
    }
}

nonisolated extension AppConfig.API.Paths {
    static let feedback = "/api/feedback"
}
