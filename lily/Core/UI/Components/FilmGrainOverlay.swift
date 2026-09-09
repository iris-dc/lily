import SwiftUI

/// Live film grain over the aurora. A handful of noise tiles are built once; each frame shows the next one,
/// tiled at device-pixel scale and blended in a single pass, so the flicker costs no per-frame noise generation.
/// Soft light would vanish on the near-black surface, so the grain adds light (`plusLighter`) instead.
struct FilmGrainOverlay: View {
    /// Seconds on the aurora's clock; `0` (Reduce Motion) always shows the first tile.
    var time: TimeInterval

    private static let tiles: [CGImage] = (0..<DesignTokens.Aurora.grainFrameCount).compactMap { frame in
        FilmGrain.makeImage(size: DesignTokens.Aurora.grainTileSize,
                            seed: DesignTokens.Aurora.grainSeed &+ UInt64(frame))
    }

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if !Self.tiles.isEmpty {
            Image(decorative: Self.tiles[frameIndex], scale: displayScale / DesignTokens.Aurora.grainPixelSize)
                .interpolation(.none)
                .resizable(resizingMode: .tile)
                .opacity(DesignTokens.Aurora.grainOpacity)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    private var frameIndex: Int {
        FilmGrain.frameIndex(at: time, frameCount: Self.tiles.count, frameRate: DesignTokens.Aurora.grainFrameRate)
    }
}
