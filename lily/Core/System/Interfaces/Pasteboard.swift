import Foundation

/// The system clipboard, behind a seam so a view model can be tested without `UIPasteboard`.
protocol Pasteboard {
    func copy(_ text: String)
}
