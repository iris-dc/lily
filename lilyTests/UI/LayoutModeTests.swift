import SwiftUI
import Testing
@testable import lily

/// The one rule behind every iPad layout: the size class says compact or regular, the width says wide.
struct LayoutModeTests {
    @Test func aCompactOrUnknownSizeClassIsCompactWhateverTheWidth() {
        #expect(LayoutMode.resolve(sizeClass: .compact, width: 2000) == .compact)
        #expect(LayoutMode.resolve(sizeClass: nil, width: 2000) == .compact)
        #expect(LayoutMode.resolve(sizeClass: .compact, width: 0) == .compact)
    }

    @Test func aRegularSizeClassIsRegularUntilTheWideWidth() {
        let threshold = DesignTokens.Layout.wideMinWidth
        #expect(LayoutMode.resolve(sizeClass: .regular, width: threshold - 1) == .regular)
        #expect(LayoutMode.resolve(sizeClass: .regular, width: threshold) == .wide)
        #expect(LayoutMode.resolve(sizeClass: .regular, width: 1366) == .wide)
    }

    @Test func onlyCompactIsNotRegular() {
        #expect(!LayoutMode.compact.isRegular)
        #expect(LayoutMode.regular.isRegular)
        #expect(LayoutMode.wide.isRegular)
    }
}

/// The card grid keeps one column on compact widths so the iPhone lists render as before.
struct AdaptiveCardGridTests {
    private typealias Grid = AdaptiveCardGrid<[SportEvent], EmptyView>

    @Test func compactAndUnknownWidthsGetOneFlexibleColumn() {
        for sizeClass in [UserInterfaceSizeClass.compact, nil] {
            let columns = Grid.columns(for: sizeClass)
            #expect(columns.count == 1)
            guard case .flexible = columns.first?.size else {
                Issue.record("expected one flexible column for \(String(describing: sizeClass))")
                continue
            }
        }
    }

    @Test func aRegularWidthGetsAdaptiveColumnsBetweenTheCardBounds() {
        let columns = Grid.columns(for: .regular)
        #expect(columns.count == 1)
        guard case .adaptive(let minimum, let maximum) = columns.first?.size else {
            Issue.record("expected an adaptive column")
            return
        }
        #expect(minimum == DesignTokens.Layout.cardMinWidth)
        #expect(maximum == DesignTokens.Layout.cardMaxWidth)
    }
}
