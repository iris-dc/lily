import Foundation

/// Body of `PUT /api/me/devices`: the token the system handed the app, and where it came from.
nonisolated struct DeviceRegistrationPayload: Encodable, Equatable, Sendable {
    let token: String
    let platform: String
    let environment: PushEnvironment
    let appVersion: String
}

/// The registration as the backend stored it; the token comes back in lower case.
nonisolated struct DeviceRegistration: Decodable, Equatable, Sendable {
    let token: String
    let environment: PushEnvironment
    let registeredAt: Date
}

/// Answer of `DELETE /api/me/devices/{token}`; `removed` is false when the token was not registered.
nonisolated struct DeviceRemoval: Decodable, Equatable, Sendable {
    let token: String
    let removed: Bool
}

/// What this device last told the backend, kept in `UserDefaults` so a launch repeats only a changed or stale one.
nonisolated struct LastDeviceRegistration: Codable, Equatable, Sendable {
    let token: String
    let userID: String
    let registeredAt: Date

    /// Whether a registration of `token` for `userID` made at `now` would tell the backend nothing new.
    func isCurrent(token: String, userID: String, now: Date, within interval: TimeInterval) -> Bool {
        self.token == token && self.userID == userID && now.timeIntervalSince(registeredAt) < interval
    }
}
