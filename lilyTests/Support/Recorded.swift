/// What a view model handed on through a closure (`onChange`, `onCreated`), in order.
@MainActor
final class Recorded<Value> {
    private(set) var values: [Value] = []

    func record(_ value: Value) {
        values.append(value)
    }
}
