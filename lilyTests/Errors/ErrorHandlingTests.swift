import Foundation
import Testing
@testable import lily

struct ErrorMessageMapperTests {
    private static let allErrors: [AppError] = [
        .authCancelled, .authFailed(provider: .apple), .providerUnavailable(provider: .apple), .invalidCredentials,
        .emailTaken, .emailNotConfirmed, .invalidConfirmationCode, .tooManyAttempts,
        .sessionExpired, .rateLimited, .network, .eventsUnavailable, .eventNotFound, .eventFull,
        .alreadyJoined, .notAParticipant, .hostCannotLeave, .tryAgain, .participationFailed, .eventCreationFailed,
        .unknown,
    ]

    /// The event branch of the mapper ends in a generic default, so a case missing from it would read
    /// "Something went wrong" and still pass a non-empty check; only `.unknown` may carry that copy.
    @Test(arguments: allErrors)
    func everyErrorHasCopy(error: AppError) {
        let message = ErrorMessageMapper.message(for: error)
        #expect(!message.title.isEmpty)
        #expect(!message.body.isEmpty)
        #expect(error == .unknown || message != ErrorMessageMapper.message(for: .unknown),
                "\(error) fell through to the generic copy")
    }

    /// Pinned so a change to the refusal copy is a deliberate diff, not a side effect of editing the mapper.
    @Test func participationRefusalsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .tryAgain).title == "Please try again")
        #expect(ErrorMessageMapper.message(for: .participationFailed).title == "Couldn't update your spot")
    }

    /// A create that fails for no named reason must not read like a join that failed.
    @Test func creationFailureHasItsOwnTitle() {
        #expect(ErrorMessageMapper.message(for: .eventCreationFailed).title == "Couldn't create your game")
    }

    /// Being throttled is not being offline; the copy asks for a pause, not for a connection check.
    @Test func rateLimitedHasItsOwnTitle() {
        #expect(ErrorMessageMapper.message(for: .rateLimited).title == "Slow down a moment")
    }

    @Test func providerFailureNamesProvider() {
        #expect(ErrorMessageMapper.message(for: .authFailed(provider: .google)).body.contains("Google"))
    }

    /// Pinned: the sheet keeps Apple and Google visible, so the copy must promise rather than apologise.
    @Test func unavailableProviderIsComingSoonAndPointsToEmail() {
        let message = ErrorMessageMapper.message(for: .providerUnavailable(provider: .google))
        #expect(message.title == "Coming soon")
        #expect(message.body == "Sign in with Google isn't available yet. Use your email for now.")
    }

    @Test func confirmationErrorsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .emailTaken).title == "Email already in use")
        #expect(ErrorMessageMapper.message(for: .emailNotConfirmed).title == "Confirm your email")
        #expect(ErrorMessageMapper.message(for: .invalidConfirmationCode).title == "That code didn't match")
        #expect(ErrorMessageMapper.message(for: .tooManyAttempts).title == "Too many attempts")
        #expect(ErrorMessageMapper.message(for: .sessionExpired).title == "Session expired")
    }

    @Test func wrappingNormalisesForeignErrors() {
        #expect(AppError.wrapping(AppError.network) == .network)
        #expect(AppError.wrapping(CancellationError()) == .authCancelled)
        #expect(AppError.wrapping(URLError(.notConnectedToInternet)) == .network)
        #expect(AppError.wrapping(NSError(domain: "x", code: 1)) == .unknown)
    }
}

@MainActor
struct ErrorCenterTests {
    @Test func reportPresentsMappedMessageAndLogs() {
        let logger = SpyLogger()
        let center = ErrorCenter(logger: logger)

        center.report(AppError.network)

        #expect(center.current?.error == .network)
        #expect(center.current?.message == ErrorMessageMapper.message(for: .network))
        #expect(logger.messages(in: .ui).count == 1)
    }

    @Test func repeatedReportsGetFreshIdentity() {
        let center = ErrorCenter(logger: SpyLogger())
        center.report(AppError.network)
        let first = center.current?.id
        center.report(AppError.network)
        #expect(center.current?.id != first)
    }

    @Test func dismissWithStaleIdIsIgnored() {
        let center = ErrorCenter(logger: SpyLogger())
        center.report(AppError.network)
        let stale = center.current!.id
        center.report(AppError.unknown)

        center.dismiss(stale)
        #expect(center.current?.error == .unknown)

        center.dismiss()
        #expect(center.current == nil)
    }

    @Test func onlyTheLatestPresenterDraws() {
        let center = ErrorCenter(logger: SpyLogger())
        let root = UUID()
        let sheet = UUID()

        center.beginPresenting(root)
        #expect(center.isTopPresenter(root))

        center.beginPresenting(sheet)
        #expect(center.isTopPresenter(sheet))
        #expect(!center.isTopPresenter(root))

        center.endPresenting(sheet)
        #expect(center.isTopPresenter(root))
    }
}
