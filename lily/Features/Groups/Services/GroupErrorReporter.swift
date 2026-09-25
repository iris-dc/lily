import Foundation

/// Where every groups screen sends a failure: the shared popup, and, when the backend asked for the current terms
/// first (`TERMS_REQUIRED` from any write), the terms sheet too, so the user is not left with a popup and no way on.
final class GroupErrorReporter {
    private let errorCenter: ErrorCenter
    private let onTermsRequired: @MainActor () -> Void

    init(errorCenter: ErrorCenter, onTermsRequired: @escaping @MainActor () -> Void) {
        self.errorCenter = errorCenter
        self.onTermsRequired = onTermsRequired
    }

    func report(_ error: any Error) {
        let appError = AppError.wrapping(error)
        errorCenter.report(appError)
        if appError == .termsRequired { onTermsRequired() }
    }
}
