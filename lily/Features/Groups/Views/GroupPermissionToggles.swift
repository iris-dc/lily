import SwiftUI

/// What members may do in the group: create events and invite others.
struct GroupPermissionToggles: View {
    @Binding var membersCanCreateEvents: Bool
    @Binding var membersCanInvite: Bool

    private typealias Copy = AppBranding.Groups.Create

    var body: some View {
        Toggle(Copy.membersCanCreateEvents, isOn: $membersCanCreateEvents)
        Toggle(Copy.membersCanInvite, isOn: $membersCanInvite)
    }
}
