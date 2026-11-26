import Foundation

/// Body of `PUT /api/me/devices`: the token the system handed the app, where it came from, and the language the app
/// shows, which the backend's reminder push follows.
nonisolated struct DeviceRegistrationPayload: Encodable, Equatable, Sendable {
    let token: String
    let platform: String
    let environment: PushEnvironment
    let appVersion: String
    let locale: String
    /// The push kinds this device muted, sorted; empty when everything may come.
    let mutedKinds: [String]
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
/// `locale` is optional because registrations stored before the app spoke more than one language have none.
nonisolated struct LastDeviceRegistration: Codable, Equatable, Sendable {
    let token: String
    let userID: String
    let locale: String?
    /// Optional like `locale`: registrations stored before the mutes existed have none, and read as none muted.
    let mutedKinds: [String]?
    let registeredAt: Date

    /// Whether registering `payload` for `userID` at `now` would tell the backend nothing new.
    func isCurrent(for payload: DeviceRegistrationPayload,
                   userID: String,
                   now: Date,
                   within interval: TimeInterval) -> Bool {
        token == payload.token && self.userID == userID && locale == payload.locale
            && (mutedKinds ?? []) == payload.mutedKinds
            && now.timeIntervalSince(registeredAt) < interval
    }
}
