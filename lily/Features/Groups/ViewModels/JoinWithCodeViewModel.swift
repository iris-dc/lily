import Foundation
import Observation

/// The "Join with code" sheet: one field that formats itself as the code is typed, and, once twelve valid symbols
/// are in, the same preview-then-join flow an invite link goes through.
@Observable
final class JoinWithCodeViewModel {
    /// Shown grouped (`KRZB-7K3M-QX9P`) and normalised as typed: separators dropped, upper-cased, look-alikes mapped,
    /// capped at the code length.
    var input = "" {
        didSet {
            let formatted = Self.format(input)
            if formatted != input { input = formatted }
        }
    }
    /// The preview of the code entered, once Continue was tapped; the sheet shows it in place of the field.
    private(set) var preview: InvitePreviewViewModel?

    private let makePreview: @MainActor (InviteCode) -> InvitePreviewViewModel

    init(makePreview: @escaping @MainActor (InviteCode) -> InvitePreviewViewModel) {
        self.makePreview = makePreview
    }

    var code: InviteCode? { InviteCode(input) }

    var canContinue: Bool { code != nil }

    /// Continue: previews the code. Nothing happens until the input is a complete code.
    func proceed() async {
        guard let code else { return }
        let preview = makePreview(code)
        self.preview = preview
        await preview.load()
    }

    /// Back to the field, keeping what was typed.
    func editCode() {
        preview = nil
    }

    private static func format(_ raw: String) -> String {
        InviteCode.grouped(String(InviteCode.normalize(raw).prefix(AppConfig.Groups.inviteCodeLength)))
    }
}
