import SwiftUI

/// The optional detail line under the address (apartment, floor, entrance): free text the draft appends to the
/// stored place name (`PlacePickingDraft.composedLocationName`), never judged as the place itself. The bare field;
/// callers add the `OptionalMarker` in their own layout (beside the row in a form, under the capsule in the wizard).
struct PlaceDetailField: View {
    @Binding var detail: String
    let identifier: String

    var body: some View {
        TextField(AppBranding.Events.Create.locationDetailPlaceholder, text: $detail)
            .textInputAutocapitalization(.sentences)
            .accessibilityIdentifier(identifier)
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
