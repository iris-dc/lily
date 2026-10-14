import Foundation
@testable import lily

/// Scriptable `FeedbackRepository`: every send is recorded and answered with a receipt, or refused with `error`;
/// `holdsRequests` parks a send until `releaseRequests()`, so a test can look at the model while one is in flight.
@MainActor
final class FakeFeedbackRepository: FeedbackRepository, HoldsRequests {
    var error: (any Error)?
    private(set) var sent: [FeedbackPayload] = []
    let hold = RequestHold()

    func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt {
        sent.append(feedback)
        try await hold.waitOrThrow()
        if let error { throw error }
        return FeedbackReceipt(id: "f-\(sent.count)", createdAt: .now)
    }
}

extension FeedbackEnvironment {
    static let fixture = FeedbackEnvironment(appVersion: "1.0 (42)",
                                             osVersion: "iOS 26.0.1",
                                             device: "iPhone17,1",
                                             locale: "en")
}
