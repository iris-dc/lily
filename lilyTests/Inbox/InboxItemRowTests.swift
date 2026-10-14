import SwiftUI
import Testing
import UIKit
@testable import lily

@MainActor
struct InboxItemRowTests {
    private let harness = GroupHarness()
    /// An iPhone's width with no height proposed, so an empty body measures zero and a card its content.
    private let fitting = CGSize(width: 390, height: UIView.layoutFittingCompressedSize.height)

    private func height(of item: InboxItem) -> CGFloat {
        let row = InboxItemRow(item: item, viewModel: harness.makeInboxViewModel())
        return UIHostingController(rootView: row).sizeThatFits(in: fitting).height
    }

    @Test func anUnknownKindDrawsNothing() {
        #expect(height(of: .unknown()) == 0)
        let bare = InboxItem(id: "bare", kind: .eventReminder, createdAt: .now)
        #expect(height(of: bare) == 0, "a known kind whose payload is missing draws nothing either")
    }

    @Test func aReminderDrawsItsCard() {
        #expect(height(of: .reminder()) > 0)
    }
}
