import Foundation

nonisolated extension Collection where Element: Equatable {
    /// The first of `candidates` this collection holds. The candidates' order decides, not the collection's: the hint
    /// under a form section names the first thing wrong in that section's field order.
    func first(of candidates: [Element]) -> Element? {
        candidates.first { contains($0) }
    }

    func first(of candidates: Element...) -> Element? {
        first(of: candidates)
    }
}
