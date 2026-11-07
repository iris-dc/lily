import Foundation

/// Copy for the caller deleting their own account; `peopleMessage(for:)` chains here. The flow's settled outcomes
/// never arrive: a 401 or `USER_NOT_FOUND` during the poll means the deletion landed (`DeletionSettle`), not a failure.
nonisolated extension ErrorMessageMapper {
    static func accountMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .deletionPlanUnavailable:
            ErrorMessage(title: localized("Couldn't check your account"), body: localized("Please try again in a moment."))
        case .accountDeletionFailed:
            ErrorMessage(title: localized("Couldn't delete your account"), body: localized("Please try again in a moment."))
        default:
            unknownMessage
        }
    }
}
