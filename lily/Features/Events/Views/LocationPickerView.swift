import MapKit
import SwiftUI

/// Picks the spot of a new game: the map moves under a fixed pin, and wherever the map settles, the point under the
/// pin is the spot. Pushed from the create form; both Done and the back button keep what the pin points at.
struct LocationPickerView: View {
    @Binding var coordinate: Coordinate?
    @State private var position: MapCameraPosition
    /// The map's frame; the pin sits at its centre, and that point is what gets converted into a coordinate.
    @State private var mapSize: CGSize = .zero
    /// The map settles once on its own when it opens; that arrival is not the user's choice.
    @State private var hasSettledOnce = false
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Events.Create

    init(coordinate: Binding<Coordinate?>) {
        _coordinate = coordinate
        _position = State(initialValue: Self.startPosition(for: coordinate.wrappedValue))
    }

    /// A spot already chosen opens as a neighbourhood around it. Without one the map follows the user, and MapKit's
    /// own default when the position is unknown, so no fixture coordinate ever stands in for a real spot.
    private static func startPosition(for coordinate: Coordinate?) -> MapCameraPosition {
        guard let coordinate else { return .userLocation(fallback: .automatic) }
        let span = AppConfig.Location.pickerRegionMeters
        let region = MKCoordinateRegion(center: coordinate.clCoordinate, latitudinalMeters: span, longitudinalMeters: span)
        return .region(region)
    }

    var body: some View {
        ContentScreen {
            // The footer takes real room instead of insetting the safe area: a `Map` draws under such insets like a
            // scroll view, which put the hint over street names and the pin off the map's centre.
            VStack(spacing: 0) {
                ZStack {
                    map
                    pin
                }
                footer
            }
        }
        .navigationTitle(Copy.mapTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton() }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { mapSize = $0 }
            .onMapCameraChange(frequency: .onEnd) { context in
                settle(under: proxy, fallback: context.camera.centerCoordinate)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.createMap)
        }
    }

    /// Every settle after the first moves the spot under the pin. The first one is skipped while the draft has no spot:
    /// it is the map arriving, so leaving without a drag keeps the spot unset instead of storing wherever it opened.
    private func settle(under proxy: MapProxy, fallback: CLLocationCoordinate2D) {
        defer { hasSettledOnce = true }
        guard hasSettledOnce || coordinate != nil else { return }
        coordinate = spotUnderPin(proxy, fallback: fallback)
    }

    /// The pin is centred on the map's frame; MapKit's own camera centre can sit elsewhere when it insets for bars, so
    /// the frame's centre is converted instead. The camera centre is only the fallback before the frame is known.
    private func spotUnderPin(_ proxy: MapProxy, fallback: CLLocationCoordinate2D) -> Coordinate {
        let center = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        return Coordinate(proxy.convert(center, from: .local) ?? fallback)
    }

    private var pin: some View {
        Image(systemName: DesignTokens.Symbols.pickedLocation)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.lilyAccent)
            .frame(width: DesignTokens.Layout.locationPickerPinSize, height: DesignTokens.Layout.locationPickerPinSize)
            .glassEffect(.regular, in: .circle)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text(Copy.mapHint)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(Copy.mapDone) { dismiss() }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.createMapDone)
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

#Preview {
    @Previewable @State var coordinate: Coordinate? = AppConfig.Location.mockCenter
    NavigationStack {
        LocationPickerView(coordinate: $coordinate)
    }
}
