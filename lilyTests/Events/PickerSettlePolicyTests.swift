import Testing
@testable import lily

@MainActor
struct PickerSettlePolicyTests {
    private let spot = Coordinate(latitude: 52.52, longitude: 13.405)
    /// The settle the map's own arrival produced on the simulator for `spot`: 6.5 cm away.
    private let arrivalNudge = Coordinate(latitude: 52.520000582795696, longitude: 13.405000000000005)
    /// One point of drag at the picker's 1.5 km span, about 4.4 m.
    private let oneDragPoint = Coordinate(latitude: 52.52004, longitude: 13.405)

    @Test func openingThePickerOnAChosenSpotKeepsIt() {
        #expect(!PickerSettlePolicy.isAChoice(arrivalNudge, current: spot, isFirstSettle: true))
    }

    @Test func aDragMovesTheSpot() {
        #expect(PickerSettlePolicy.isAChoice(oneDragPoint, current: spot, isFirstSettle: false))
    }

    @Test func aPickerWithoutASpotSkipsTheFirstSettle() {
        #expect(!PickerSettlePolicy.isAChoice(spot, current: nil, isFirstSettle: true))
        #expect(PickerSettlePolicy.isAChoice(spot, current: nil, isFirstSettle: false))
    }

    @Test func theMoveIsJudgedNotTheSettleCount() {
        #expect(!PickerSettlePolicy.isAChoice(arrivalNudge, current: spot, isFirstSettle: false))
        #expect(PickerSettlePolicy.isAChoice(oneDragPoint, current: spot, isFirstSettle: true))
    }

    @Test func aMoveAtTheToleranceCountsAndJustUnderDoesNot() {
        let move = spot.distance(to: oneDragPoint)
        let justUnder = move + 0.001

        #expect(PickerSettlePolicy.isAChoice(oneDragPoint, current: spot, isFirstSettle: false, minimumMoveMeters: move))
        #expect(!PickerSettlePolicy.isAChoice(oneDragPoint, current: spot, isFirstSettle: false, minimumMoveMeters: justUnder))
    }
}
