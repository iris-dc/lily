import SwiftUI
import Testing
@testable import lily

@MainActor
struct EventListLayoutTests {
    @Test func onlyAWideWindowWithAMapGetsTheSideBySideLayout() {
        #expect(EventListLayout.resolve(mode: .wide, showsMap: true) == .sideBySide)
        #expect(EventListLayout.resolve(mode: .wide, showsMap: false) == .switchable)
        #expect(EventListLayout.resolve(mode: .regular, showsMap: true) == .switchable)
        #expect(EventListLayout.resolve(mode: .compact, showsMap: true) == .switchable)
    }
}

@MainActor
struct TileGridTests {
    private typealias Grid = TileGrid<[SportGroup], EmptyView>

    @Test func theGridShowsTheFirstFewAndKeepsTheirOrder() {
        let groups = (0..<12).map { SportGroup.fixture(id: "g\($0)", name: "Group \($0)") }
        let shown = Grid.shown(of: groups)
        #expect(shown.count == DesignTokens.Layout.regularTileCount)
        #expect(shown.map(\.id) == groups.prefix(DesignTokens.Layout.regularTileCount).map(\.id))
    }

    @Test func fewerThanTheCapAreAllShown() {
        let groups = [SportGroup.fixture(id: "a", name: "A"), SportGroup.fixture(id: "b", name: "B")]
        #expect(Grid.shown(of: groups).map(\.id) == ["a", "b"])
    }

    @Test func columnsAdaptFromTheTileWidth() {
        let columns = Grid.columns
        #expect(columns.count == 1)
        guard case .adaptive(let minimum, _) = columns.first?.size else {
            Issue.record("expected an adaptive column")
            return
        }
        #expect(minimum == DesignTokens.Layout.tileMinWidth)
    }
}
