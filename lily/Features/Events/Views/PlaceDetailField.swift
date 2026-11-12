import SwiftUI

/// The optional detail line under the address (apartment, floor, entrance): free text the draft appends to the
/// stored place name (`PlacePickingDraft.composedLocationName`), never judged as the place itself. The bare field;
/// callers add the `OptionalMarker` in their own layout (beside the row in a form, under the capsule in the wizard).
struct PlaceDetailField: View {
    @Binding var detail: String
    let identifier: String

    /// The scroll mark the wizard's place pages reveal while suggestions are shown: centering the detail line — the
    /// middle of the place cluster — keeps the typed field visible above it and the map row and hint clear of the
    /// bottom bar's capsule below it. Inert in the edit forms, which scroll as plain forms.
    static let revealMark = "place-detail-field"

    var body: some View {
        TextField(AppBranding.Events.Create.locationDetailPlaceholder, text: $detail)
            .textInputAutocapitalization(.sentences)
            .accessibilityIdentifier(identifier)
            .id(Self.revealMark)
    }
}

#Preview {
    @Previewable @State var detail = ""
    NavigationStack {
        Form {
            PlaceDetailField(detail: $detail, identifier: AccessibilityIdentifiers.createLocationDetail)
        }
    }
}
