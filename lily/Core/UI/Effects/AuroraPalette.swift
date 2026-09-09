/// What each cell of the ember mesh paints. `LilyTheme` maps roles to asset colors,
/// so this stays free of `@MainActor` asset symbols and can be unit tested.
nonisolated enum AuroraRole: Equatable {
    /// Plain surface color; the mesh fades into the screen background here.
    case surface
    /// The maroon mass, at one of three densities.
    case mass(MassDensity)
    /// The hot core whose opacity breathes.
    case core
    /// The single faint amber ember.
    case ember

    enum MassDensity {
        case dense, mid, thin
    }
}

/// Row-major role layout for the 4x4 mesh: two maroon masses, upper-left behind the headline and lower-right
/// behind the button, joined by a thin diagonal with a darker valley on either side so the screen keeps its depth.
/// The core sits on the top edge so its bloom lights the headline from above instead of swallowing the red last
/// line; the top-right corner stays surface and one amber ember warms the bottom-left corner.
nonisolated enum AuroraPalette {
    static let roles: [AuroraRole] = [
        .mass(.dense), .core, .mass(.mid), .surface,
        .mass(.dense), .mass(.dense), .mass(.thin), .surface,
        .surface, .mass(.thin), .mass(.mid), .mass(.dense),
        .ember, .surface, .mass(.dense), .mass(.dense),
    ]

    /// Opacity of a mass cell before the ripple scales it.
    static func massOpacity(_ density: AuroraRole.MassDensity) -> Double {
        switch density {
        case .dense: DesignTokens.Aurora.massDense
        case .mid: DesignTokens.Aurora.massMid
        case .thin: DesignTokens.Aurora.massThin
        }
    }
}
