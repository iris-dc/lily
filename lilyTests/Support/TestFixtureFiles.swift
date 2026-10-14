import Foundation

/// The non-Swift fixtures of the test bundle (`lilyTests/Fixtures`, copied in by the synchronized group, which has
/// flattened the `pairings/` folder, hence the root lookup first). Swift Testing suites are structs, so the private class
/// carries the bundle.
enum TestFixtureFiles {
    private final class BundleToken {}

    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    static func url(forResource name: String, withExtension ext: String, subdirectory: String? = nil) -> URL? {
        bundle.url(forResource: name, withExtension: ext)
            ?? subdirectory.flatMap { bundle.url(forResource: name, withExtension: ext, subdirectory: $0) }
    }

    /// The two-second, 320x180 clip (`tiny.mp4`, 24 KB, `ffmpeg testsrc2`).
    static var tinyVideo: URL { url(forResource: "tiny", withExtension: "mp4")! }
}
