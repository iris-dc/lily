import Foundation

nonisolated extension String {
    /// The first letters of the first two words, upper-cased: "Kreuzberg Kickers" is "KK", "Marta" is "M".
    var initials: String {
        split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
