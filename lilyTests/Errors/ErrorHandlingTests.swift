import Foundation
import Testing
@testable import lily

struct ErrorMessageMapperTests {
    private static let allErrors: [AppError] = [
        .authCancelled, .authFailed(provider: .apple), .invalidCredentials,
        .sessionExpired, .network, .eventsUnavailable, .eventNotFound, .eventFull,
        .alreadyJoined, .notAParticipant, .hostCannotLeave, .unknown,
    ]

    @Test(arguments: allErrors)
    func everyErrorHasCopy(error: AppError) {
        let message = ErrorMessageMapper.message(for: error)
        #expect(!message.title.isEmpty)
        #expect(!message.body.isEmpty)
    }

    @Test func providerFailureNamesProvider() {
        #expect(ErrorMessageMapper.message(for: .authFailed(provider: .google)).body.contains("Google"))
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
