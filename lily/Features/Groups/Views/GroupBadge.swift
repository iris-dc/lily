import SwiftUI

/// The group an event is hosted in, as a chip on its card. Last in line for space, and capped in width while it shares
/// a row with the relative-time caption, so that caption keeps its own; on a row of its own the cap comes off.
struct GroupBadge: View {
    let ref: EventGroupRef
    var capsWidth = true

    var body: some View {
        Label(ref.name, systemImage: DesignTokens.Symbols.groups)
            .lilyChip(.regular)
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(-1)
            .frame(maxWidth: capsWidth ? DesignTokens.Layout.groupBadgeMaxWidth : nil)
    }
}

#Preview {
    ContentScreen {
        GroupBadge(ref: MockGroupFixtures.make(now: .now)[0].ref)
    }
}
