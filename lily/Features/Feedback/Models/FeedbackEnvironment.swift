import Foundation

/// What every message carries besides the words, so a bug report can be reproduced: the app version the backend
/// already sees in `X-App-Version`, the OS version, the device model and the app's language. Nothing here names the
/// person; the footer of the form shows it before the send.
nonisolated struct FeedbackEnvironment: Equatable, Sendable {
    let appVersion: String
    let osVersion: String
    let device: String
    let locale: String

    /// "1.0 (42) · iOS 26.0.1 · iPhone17,1", the footer's summary.
    var summary: String {
        [appVersion, osVersion, device].joined(separator: AppBranding.Events.captionSeparator)
    }

    static func current(appVersion: AppVersion = .current(),
                        languageCode: String,
                        processInfo: ProcessInfo = .processInfo) -> FeedbackEnvironment {
        FeedbackEnvironment(appVersion: appVersion.headerValue,
                            osVersion: osVersionText(processInfo.operatingSystemVersion),
                            device: DeviceModel.identifier(environment: processInfo.environment),
                            locale: languageCode)
    }

    /// "iOS 26.0" or "iOS 26.0.1": the patch only when there is one.
    static func osVersionText(_ version: OperatingSystemVersion) -> String {
        var text = "\(AppConfig.Feedback.osName) \(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion > 0 { text += ".\(version.patchVersion)" }
        return text
    }
}

/// The hardware model identifier ("iPhone17,1"), from `uname` on a device and from the simulator's environment on a
/// Mac, where `uname` would answer the host's architecture.
nonisolated enum DeviceModel {
    static func identifier(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let simulated = environment[AppConfig.Feedback.simulatorModelKey], !simulated.isEmpty {
            return simulated
        }
        return machine()
    }

    private static func machine() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: info.machine) { field in
            field.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: info.machine)) { String(cString: $0) }
        }
    }
}
