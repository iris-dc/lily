import Foundation
@testable import lily

/// Scriptable `FeedbackRepository`: every send is recorded and answered with a receipt, or refused with `error`;
/// `holdsRequests` parks a send until `releaseRequests()`, so a test can look at the model while one is in flight.
@MainActor
final class FakeFeedbackRepository: FeedbackRepository {
    var error: (any Error)?
    private(set) var sent: [FeedbackPayload] = []
    private let hold = RequestHold()

    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }

    func releaseRequests() {
        hold.release()
    }

    func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt {
        sent.append(feedback)
        await hold.wait()
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
