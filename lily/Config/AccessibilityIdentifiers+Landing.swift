import Foundation

/// Identifiers of the landing's intro. `introPager` is mirrored by hand in `lilyUITests` like the rest; the slides'
/// name their page in a hierarchy dump and the test reads the page on screen from the headlines instead.
nonisolated extension AccessibilityIdentifiers {
    /// The vertical pager of slides; the two buttons under it are found by their titles.
    static let introPager = "intro-pager"

    /// One page of the pager, e.g. `intro-slide-join`.
    static func introSlide(_ slide: IntroSlide) -> String {
        "intro-slide-\(slide.rawValue)"
    }
}
