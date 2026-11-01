import Foundation

nonisolated extension String {
    /// The length as Laurel measures a display name (`codePointCount`): code points, where `wireLength` counts UTF-16
    /// units, so an emoji is one here and two there.
    var codePointCount: Int { unicodeScalars.count }

    /// The first `maxLength` code points, never cut inside one.
    func prefix(codePoints maxLength: Int) -> String {
        String(String.UnicodeScalarView(unicodeScalars.prefix(maxLength)))
    }
}
