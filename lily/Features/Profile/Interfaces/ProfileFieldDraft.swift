import Foundation

/// A text of the caller's profile as typed and judged (`DisplayNameDraft`, `AboutDraft`): what `ProfileFieldViewModel`
/// needs of one. Limits are measured in code points as Laurel measures them, so a text that passes is stored as typed.
nonisolated protocol ProfileFieldDraft: Equatable, Sendable {
    associatedtype Issue: Equatable

    init(text: String)
    var text: String { get set }
    /// What goes out: the text trimmed, as the backend stores it.
    var trimmedText: String { get }
    /// Empty when the draft may go out.
    var issues: [Issue] { get }
    var isValid: Bool { get }
    /// The line under the field, if any.
    var hint: String? { get }
}
