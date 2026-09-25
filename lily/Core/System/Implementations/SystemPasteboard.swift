import UIKit

final class SystemPasteboard: Pasteboard {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
