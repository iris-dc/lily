import Foundation

/// Copy for what a host does to their own game: creating and editing it. In its own file because `eventMessage(for:)`
/// is at SwiftLint's complexity limit; it falls through to here.
nonisolated extension ErrorMessageMapper {
    static func hostMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .eventCreationFailed:
            ErrorMessage(title: "Couldn't create your game", body: "Check the details and try again in a moment.")
        case .eventUpdateFailed:
            ErrorMessage(title: "Couldn't save your changes", body: "Check the details and try again in a moment.")
        case .notHost:
            ErrorMessage(title: "Not your game", body: "Only the host can change a game.")
        case .capacityTooLow:
            ErrorMessage(title: "Too few spots", body: "Keep at least as many spots as players who already joined.")
        default:
            unknownMessage
        }
    }
}
